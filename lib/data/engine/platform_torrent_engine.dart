import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/piece_priority.dart';
import '../../domain/entities/stream_telemetry.dart';
import '../../domain/entities/torrent_info.dart';
import '../sequential/piece_priority_calculator.dart';
import '../sequential/stream_window_manager.dart';
import 'torrent_engine.dart';

/// Platform implementation of [TorrentEngine] bridging via MethodChannel and EventChannel
/// to Android (jlibtorrent in Kotlin) and iOS (libtorrent in Swift/Obj-C++)
class PlatformTorrentEngine implements TorrentEngine {
  static const MethodChannel _methodChannel =
      MethodChannel('com.streammagnet/torrent_engine');
  static const EventChannel _eventChannel =
      EventChannel('com.streammagnet/torrent_events');

  final StreamWindowManager windowManager;
  final Map<String, StreamController<StreamTelemetry>> _telemetryControllers = {};
  StreamSubscription<dynamic>? _eventSubscription;
  PiecePriorityCalculator? _currentCalc;

  PlatformTorrentEngine({required this.windowManager});

  @override
  Future<void> initialize({required String cachePath}) async {
    try {
      await _methodChannel.invokeMethod('init', {
        'cachePath': cachePath,
        'maxConnections': AppConstants.defaultMaxConnections,
        'uploadLimit': AppConstants.defaultUploadLimitBytesPerSec,
      });

      _subscribeToEvents();
      AppLogger.info('PlatformTorrentEngine initialized successfully');
    } catch (e, st) {
      AppLogger.error('Failed to initialize PlatformTorrentEngine', e, st);
      throw TorrentEngineFailure('Failed to initialize native torrent engine: $e', e);
    }
  }

  void _subscribeToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type'] as String?;
          if (type == 'piece_downloaded') {
            final pieceIndex = (event['pieceIndex'] as num).toInt();
            windowManager.onPieceDownloaded(pieceIndex);
          } else if (type == 'telemetry') {
            _handleTelemetryEvent(event);
          }
        }
      },
      onError: (dynamic error) {
        AppLogger.error('Error on torrent EventChannel', error);
      },
    );
  }

  void _handleTelemetryEvent(Map event) {
    final infoHash = event['infoHash'] as String?;
    if (infoHash == null) return;

    final controller = _telemetryControllers[infoHash];
    if (controller == null || controller.isClosed) return;

    final calc = _currentCalc;
    final bufferAhead = calc != null ? windowManager.calculateBufferAheadBytes(calc) : 0;

    final telemetry = StreamTelemetry(
      downloadSpeedBytesPerSec: (event['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      uploadSpeedBytesPerSec: (event['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      activePeers: (event['activePeers'] as num?)?.toInt() ?? 0,
      seedCount: (event['seedCount'] as num?)?.toInt() ?? 0,
      bufferAheadBytes: bufferAhead,
      bufferAheadSeconds: bufferAhead / (1.5 * 1024 * 1024),
      totalBytes: (event['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (event['downloadedBytes'] as num?)?.toInt() ?? 0,
      pieceBitfield: (event['bitfield'] as List?)?.cast<bool>() ?? const [],
    );

    controller.add(telemetry);
  }

  @override
  Future<TorrentInfo> resolveMetadata(
    String magnetOrTorrentPath, {
    Duration timeout = AppConstants.metadataTimeout,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'resolveMetadata',
        {
          'uri': magnetOrTorrentPath,
          'timeoutMs': timeout.inMilliseconds,
        },
      );

      if (result == null) {
        throw const MetadataTimeoutFailure();
      }

      final filesList = (result['files'] as List).map((f) {
        final map = f as Map;
        return TorrentFileItem(
          index: (map['index'] as num).toInt(),
          path: map['path'] as String,
          length: (map['length'] as num).toInt(),
          offset: (map['offset'] as num).toInt(),
        );
      }).toList();

      return TorrentInfo(
        infoHash: result['infoHash'] as String,
        name: result['name'] as String,
        totalBytes: (result['totalBytes'] as num).toInt(),
        pieceLength: (result['pieceLength'] as num).toInt(),
        pieceCount: (result['pieceCount'] as num).toInt(),
        files: filesList,
        trackers: (result['trackers'] as List?)?.cast<String>() ?? const [],
      );
    } on PlatformException catch (e) {
      if (e.code == 'METADATA_TIMEOUT') {
        throw const MetadataTimeoutFailure();
      }
      if (e.code == 'DEAD_TORRENT') {
        throw const DeadTorrentFailure();
      }
      throw TorrentEngineFailure('Engine error resolving metadata: ${e.message}', e);
    }
  }

  @override
  Future<void> startSession({
    required String infoHash,
    required int fileIndex,
    required PiecePriorityCalculator priorityCalc,
  }) async {
    _currentCalc = priorityCalc;
    final schedule = priorityCalc.computeSchedule(
      playheadByte: 0,
      isInitialPlayback: true,
    );

    await _methodChannel.invokeMethod('startSession', {
      'infoHash': infoHash,
      'fileIndex': fileIndex,
      'fileOffset': priorityCalc.fileOffset,
      'fileLength': priorityCalc.fileLength,
      'pieceLength': priorityCalc.pieceLength,
      'priorities': schedule.priorities.map((k, v) => MapEntry(k.toString(), v.rawValue)),
      'deadlines': schedule.deadlines.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  @override
  Future<void> updatePlayhead(String infoHash, int byteOffset) async {
    windowManager.updatePlayhead(byteOffset);
    final calc = _currentCalc;
    if (calc != null) {
      final schedule = calc.computeSchedule(playheadByte: byteOffset);
      await _methodChannel.invokeMethod('updatePrioritiesAndDeadlines', {
        'infoHash': infoHash,
        'priorities': schedule.priorities.map((k, v) => MapEntry(k.toString(), v.rawValue)),
        'deadlines': schedule.deadlines.map((k, v) => MapEntry(k.toString(), v)),
      });
    }
  }

  @override
  Future<void> setPiecePriority(
    String infoHash,
    int pieceIndex,
    PiecePriority priority,
  ) async {
    await _methodChannel.invokeMethod('setPiecePriority', {
      'infoHash': infoHash,
      'pieceIndex': pieceIndex,
      'priority': priority.rawValue,
    });
  }

  @override
  Future<void> setPieceDeadline(
    String infoHash,
    int pieceIndex,
    int deadlineMs,
  ) async {
    await _methodChannel.invokeMethod('setPieceDeadline', {
      'infoHash': infoHash,
      'pieceIndex': pieceIndex,
      'deadlineMs': deadlineMs,
    });
  }

  @override
  Future<List<int>> readPiece(String infoHash, int pieceIndex) async {
    final result = await _methodChannel.invokeMethod<List<int>>('readPiece', {
      'infoHash': infoHash,
      'pieceIndex': pieceIndex,
    });
    return result ?? const [];
  }

  @override
  Future<List<int>> readRange(
    String infoHash,
    int fileIndex,
    int byteStart,
    int byteEnd,
  ) async {
    final result = await _methodChannel.invokeMethod<List<int>>('readRange', {
      'infoHash': infoHash,
      'fileIndex': fileIndex,
      'byteStart': byteStart,
      'byteEnd': byteEnd,
    });
    return result ?? const [];
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
    await _methodChannel.invokeMethod('pause', {'infoHash': infoHash});
  }

  @override
  Future<void> resume(String infoHash) async {
    await _methodChannel.invokeMethod('resume', {'infoHash': infoHash});
  }

  @override
  Future<void> stop(String infoHash) async {
    await _methodChannel.invokeMethod('stop', {'infoHash': infoHash});
    _currentCalc = null;
    windowManager.reset();
  }

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    for (final c in _telemetryControllers.values) {
      await c.close();
    }
    _telemetryControllers.clear();
    windowManager.dispose();
  }
}
