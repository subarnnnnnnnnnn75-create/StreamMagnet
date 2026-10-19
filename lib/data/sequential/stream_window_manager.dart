import 'dart:async';
import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import 'piece_priority_calculator.dart';

/// Manages piece downloading state, ready threshold verification, and range wait blocking
class StreamWindowManager {
  final Set<int> _downloadedPieces = <int>{};
  final Map<int, List<Completer<void>>> _pieceWaiters = {};
  final StreamController<Set<int>> _pieceUpdateController =
      StreamController<Set<int>>.broadcast();

  int _currentPlayheadByte = 0;
  int readyThresholdBytes;

  StreamWindowManager({
    this.readyThresholdBytes = AppConstants.defaultReadyThresholdBytes,
  });

  Stream<Set<int>> get onPieceUpdates => _pieceUpdateController.stream;

  Set<int> get downloadedPieces => Set.unmodifiable(_downloadedPieces);

  int get currentPlayheadByte => _currentPlayheadByte;

  void setReadyThreshold(int bytes) {
    readyThresholdBytes = bytes;
  }

  void updatePlayhead(int playheadByte) {
    _currentPlayheadByte = playheadByte;
  }

  bool isPieceDownloaded(int pieceIndex) => _downloadedPieces.contains(pieceIndex);

  /// Called when the torrent engine downloads and verifies a piece
  void onPieceDownloaded(int pieceIndex) {
    if (_downloadedPieces.add(pieceIndex)) {
      _pieceUpdateController.add(Set.unmodifiable(_downloadedPieces));

      // Resolve any pending waiters for this piece
      final waiters = _pieceWaiters.remove(pieceIndex);
      if (waiters != null) {
        for (final completer in waiters) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      }
    }
  }

  /// Bulk update for initial state or restored session
  void setInitialDownloadedPieces(Iterable<int> pieces) {
    for (final p in pieces) {
      onPieceDownloaded(p);
    }
  }

  /// Checks if the stream has reached the "Ready to play" threshold:
  /// 1. Header pieces downloaded
  /// 2. Initial buffer window downloaded (from file start or playhead)
  bool isReadyToPlay(
    PiecePriorityCalculator calc, {
    int? customReadyThresholdBytes,
  }) {
    final threshold = customReadyThresholdBytes ?? readyThresholdBytes;
    final schedule = calc.computeSchedule(
      playheadByte: _currentPlayheadByte,
      isInitialPlayback: true,
    );

    // 1. Check header pieces
    for (final p in schedule.headerPieces) {
      if (!_downloadedPieces.contains(p)) {
        return false;
      }
    }

    // 2. Check initial buffer pieces
    final initialBufferPieces = calc.getPiecesForByteRange(
      _currentPlayheadByte,
      threshold,
    );
    for (final p in initialBufferPieces) {
      if (!_downloadedPieces.contains(p)) {
        return false;
      }
    }

    return true;
  }

  /// Waits until all specified piece indices have been downloaded, or times out
  Future<void> waitForPieces(
    Set<int> pieceIndices, {
    Duration timeout = AppConstants.pieceWaitTimeout,
  }) async {
    final missing = pieceIndices.difference(_downloadedPieces);
    if (missing.isEmpty) return;

    AppLogger.debug(
      'StreamWindowManager: waiting for ${missing.length} pieces (${missing.take(5).join(", ")}...)',
    );

    final completers = <Completer<void>>[];
    for (final p in missing) {
      final c = Completer<void>();
      _pieceWaiters.putIfAbsent(p, () => []).add(c);
      completers.add(c);
    }

    try {
      await Future.wait(completers.map((c) => c.future)).timeout(timeout);
    } on TimeoutException {
      AppLogger.warning(
        'StreamWindowManager: Timed out waiting for pieces: ${missing.take(10).join(", ")}',
      );
      throw DeadTorrentFailure(
        'Timed out waiting for video pieces ($timeout). The swarm may be slow or have insufficient seeds.',
      );
    }
  }

  /// Waits until the required byte range has been downloaded and is available for reading
  Future<void> waitForByteRange(
    int startByte,
    int length,
    PiecePriorityCalculator calc, {
    Duration timeout = AppConstants.pieceWaitTimeout,
  }) async {
    final requiredPieces = calc.getPiecesForByteRange(startByte, length);
    await waitForPieces(requiredPieces, timeout: timeout);
  }

  /// Computes contiguous buffer-ahead in bytes starting from current playhead
  int calculateBufferAheadBytes(PiecePriorityCalculator calc) {
    int bufferBytes = 0;
    final currentPiece = (calc.fileOffset + _currentPlayheadByte) ~/ calc.pieceLength;

    for (int p = currentPiece; p <= calc.fileEndPiece; p++) {
      if (_downloadedPieces.contains(p)) {
        if (p == currentPiece) {
          final pieceStartInFile = p * calc.pieceLength - calc.fileOffset;
          final downloadedInPiece =
              (pieceStartInFile + calc.pieceLength) - _currentPlayheadByte;
          bufferBytes += max(0, min(downloadedInPiece, calc.pieceLength));
        } else {
          final pieceBounds = calc.getPieceByteRange(p);
          bufferBytes += (pieceBounds.end - pieceBounds.start);
        }
      } else {
        // Contiguous buffer stops at first missing piece
        break;
      }
    }

    return bufferBytes;
  }

  void reset() {
    _downloadedPieces.clear();
    for (final list in _pieceWaiters.values) {
      for (final c in list) {
        if (!c.isCompleted) {
          c.completeError(
            const TorrentEngineFailure('Stream session was reset or stopped'),
          );
        }
      }
    }
    _pieceWaiters.clear();
    _currentPlayheadByte = 0;
  }

  void dispose() {
    reset();
    _pieceUpdateController.close();
  }
}
