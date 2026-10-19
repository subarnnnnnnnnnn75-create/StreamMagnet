import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/magnet_parser.dart';
import '../../domain/entities/piece_priority.dart';
import '../../domain/entities/stream_telemetry.dart';
import '../../domain/entities/torrent_info.dart';
import '../sequential/piece_priority_calculator.dart';
import '../sequential/stream_window_manager.dart';
import 'torrent_engine.dart';

/// In-memory simulated TorrentEngine for deterministic testing, benchmarks, and fallback
class SimulatedTorrentEngine implements TorrentEngine {
  final StreamWindowManager windowManager;
  final Map<String, TorrentInfo> _torrents = {};
  final Map<String, StreamController<StreamTelemetry>> _telemetryControllers = {};
  final Map<int, Uint8List> _pieceStore = {};

  bool _isInitialized = false;
  Timer? _downloadSimulationTimer;
  PiecePriorityCalculator? _currentCalc;
  String? _activeInfoHash;
  bool _isPaused = false;
  double _simulatedSpeedBytesPerSec = 4 * 1024 * 1024; // 4 MB/s default
  int _activePeers = 24;
  int _seedCount = 18;

  SimulatedTorrentEngine({required this.windowManager});

  void setSimulatedSpeed(double bytesPerSec) {
    _simulatedSpeedBytesPerSec = bytesPerSec;
  }

  void setSwarmHealth({required int peers, required int seeds}) {
    _activePeers = peers;
    _seedCount = seeds;
  }

  @override
  Future<void> initialize({required String cachePath}) async {
    _isInitialized = true;
  }

  @override
  Future<TorrentInfo> resolveMetadata(
    String magnetOrTorrentPath, {
    Duration timeout = AppConstants.metadataTimeout,
  }) async {
    if (!_isInitialized) {
      throw const TorrentEngineFailure('TorrentEngine is not initialized');
    }

    final magnet = MagnetParser.tryParse(magnetOrTorrentPath);
    final String hash = magnet?.infoHash ?? '0123456789abcdef0123456789abcdef01234567';
    final String name = magnet?.displayName ?? 'Big Buck Bunny (Simulated)';

    // Generate a simulated torrent with 1 large video file and 1 subtitle
    const pieceLength = 2 * 1024 * 1024; // 2 MB pieces
    const videoLength = 120 * 1024 * 1024; // 120 MB
    const subLength = 50 * 1024; // 50 KB

    final files = [
      const TorrentFileItem(
        index: 0,
        path: 'BigBuckBunny_1080p.mp4',
        length: videoLength,
        offset: 0,
        isSelected: true,
      ),
      const TorrentFileItem(
        index: 1,
        path: 'subs/English.srt',
        length: subLength,
        offset: videoLength,
        isSelected: false,
      ),
    ];

    final totalBytes = videoLength + subLength;
    final pieceCount = (totalBytes + pieceLength - 1) ~/ pieceLength;

    final info = TorrentInfo(
      infoHash: hash,
      name: name,
      totalBytes: totalBytes,
      pieceLength: pieceLength,
      pieceCount: pieceCount,
      files: files,
      trackers: magnet?.trackers ?? ['udp://tracker.opentrackr.org:1337/announce'],
    );

    _torrents[hash] = info;
    return info;
  }

  @override
  Future<void> startSession({
    required String infoHash,
    required int fileIndex,
    required PiecePriorityCalculator priorityCalc,
  }) async {
    _activeInfoHash = infoHash;
    _currentCalc = priorityCalc;
    _isPaused = false;

    _telemetryControllers.putIfAbsent(
      infoHash,
      () => StreamController<StreamTelemetry>.broadcast(),
    );

    _startDownloadLoop();
  }

  void _startDownloadLoop() {
    _downloadSimulationTimer?.cancel();
    _downloadSimulationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _stepSimulation(),
    );
  }

  void _stepSimulation() {
    if (_isPaused || _currentCalc == null || _activeInfoHash == null) return;
    final calc = _currentCalc!;

    final schedule = calc.computeSchedule(
      playheadByte: windowManager.currentPlayheadByte,
      isInitialPlayback: windowManager.downloadedPieces.isEmpty,
    );

    // Download order: urgent pieces first, then headers/tail, then lookahead, then rest
    int? nextPieceToDownload;

    // Check urgent
    for (final p in schedule.urgentPieces) {
      if (!windowManager.isPieceDownloaded(p)) {
        nextPieceToDownload = p;
        break;
      }
    }

    // Check headers/tails
    if (nextPieceToDownload == null) {
      for (final p in schedule.headerPieces.followedBy(schedule.tailPieces)) {
        if (!windowManager.isPieceDownloaded(p)) {
          nextPieceToDownload = p;
          break;
        }
      }
    }

    // Check lookahead
    if (nextPieceToDownload == null) {
      for (final p in schedule.lookaheadPieces) {
        if (!windowManager.isPieceDownloaded(p)) {
          nextPieceToDownload = p;
          break;
        }
      }
    }

    // Check general file pieces
    if (nextPieceToDownload == null) {
      for (int p = calc.fileStartPiece; p <= calc.fileEndPiece; p++) {
        if (!windowManager.isPieceDownloaded(p)) {
          nextPieceToDownload = p;
          break;
        }
      }
    }

    if (nextPieceToDownload != null) {
      // Store dummy piece bytes filled with predictable pattern
      final pieceBounds = calc.getPieceByteRange(nextPieceToDownload);
      final pieceSize = pieceBounds.end - pieceBounds.start;
      final dummyBytes = Uint8List(pieceSize);
      for (int i = 0; i < dummyBytes.length; i++) {
        dummyBytes[i] = (nextPieceToDownload + i) % 256;
      }
      _pieceStore[nextPieceToDownload] = dummyBytes;

      windowManager.onPieceDownloaded(nextPieceToDownload);
    }

    _emitTelemetry();
  }

  void _emitTelemetry() {
    final infoHash = _activeInfoHash;
    final calc = _currentCalc;
    if (infoHash == null || calc == null) return;

    final controller = _telemetryControllers[infoHash];
    if (controller == null || controller.isClosed) return;

    final bitfield = List.generate(
      calc.pieceCount,
      (index) => windowManager.isPieceDownloaded(index),
    );

    final bufferAheadBytes = windowManager.calculateBufferAheadBytes(calc);
    final downloadedBytes = windowManager.downloadedPieces.length * calc.pieceLength;

    final telemetry = StreamTelemetry(
      downloadSpeedBytesPerSec: _isPaused ? 0.0 : _simulatedSpeedBytesPerSec,
      uploadSpeedBytesPerSec: _isPaused ? 0.0 : 45 * 1024,
      activePeers: _activePeers,
      seedCount: _seedCount,
      bufferAheadBytes: bufferAheadBytes,
      bufferAheadSeconds: bufferAheadBytes / (1.5 * 1024 * 1024), // ~1.5 MB/s bitrate
      totalBytes: calc.fileLength,
      downloadedBytes: min(downloadedBytes, calc.fileLength),
      pieceBitfield: bitfield,
    );

    controller.add(telemetry);
  }

  @override
  Future<void> updatePlayhead(String infoHash, int byteOffset) async {
    windowManager.updatePlayhead(byteOffset);
  }

  @override
  Future<void> setPiecePriority(
    String infoHash,
    int pieceIndex,
    PiecePriority priority,
  ) async {
    // No-op for simulated engine
  }

  @override
  Future<void> setPieceDeadline(
    String infoHash,
    int pieceIndex,
    int deadlineMs,
  ) async {
    // No-op for simulated engine
  }

  @override
  Future<List<int>> readPiece(String infoHash, int pieceIndex) async {
    if (_pieceStore.containsKey(pieceIndex)) {
      return _pieceStore[pieceIndex]!;
    }
    // Generate dummy piece if not yet stored
    final calc = _currentCalc;
    final pieceLen = calc?.pieceLength ?? (2 * 1024 * 1024);
    return Uint8List(pieceLen);
  }

  @override
  Future<List<int>> readRange(
    String infoHash,
    int fileIndex,
    int byteStart,
    int byteEnd,
  ) async {
    final calc = _currentCalc;
    if (calc == null) throw const TorrentEngineFailure('No active session');

    final length = byteEnd - byteStart;
    final startPiece = (calc.fileOffset + byteStart) ~/ calc.pieceLength;
    final endPiece = (calc.fileOffset + byteEnd - 1) ~/ calc.pieceLength;

    final result = <int>[];
    for (int p = startPiece; p <= endPiece; p++) {
      final pieceBytes = await readPiece(infoHash, p);
      final pieceStartByte = p * calc.pieceLength - calc.fileOffset;

      final sliceStart = max(0, byteStart - pieceStartByte);
      final sliceEnd = min(pieceBytes.length, byteEnd - pieceStartByte);

      if (sliceStart < sliceEnd && sliceStart < pieceBytes.length) {
        result.addAll(pieceBytes.sublist(sliceStart, sliceEnd));
      }
    }

    return result.take(length).toList();
  }

  @override
  Stream<StreamTelemetry> getTelemetryStream(String infoHash) {
    return _telemetryControllers
        .putIfAbsent(
          infoHash,
          () => StreamController<StreamTelemetry>.broadcast(),
        )
        .stream;
  }

  @override
  Future<void> pause(String infoHash) async {
    _isPaused = true;
    _emitTelemetry();
  }

  @override
  Future<void> resume(String infoHash) async {
    _isPaused = false;
    _emitTelemetry();
  }

  @override
  Future<void> stop(String infoHash) async {
    _downloadSimulationTimer?.cancel();
    _isPaused = false;
    _currentCalc = null;
    _activeInfoHash = null;
    _pieceStore.clear();
    windowManager.reset();
  }

  @override
  Future<void> dispose() async {
    await stop(_activeInfoHash ?? '');
    for (final controller in _telemetryControllers.values) {
      await controller.close();
    }
    _telemetryControllers.clear();
    windowManager.dispose();
  }
}
