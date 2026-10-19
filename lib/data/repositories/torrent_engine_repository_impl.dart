import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/stream_state.dart';
import '../../domain/entities/stream_telemetry.dart';
import '../../domain/entities/torrent_info.dart';
import '../../domain/repositories/torrent_engine_repository.dart';
import '../cache/cache_manager.dart';
import '../engine/torrent_engine.dart';
import '../http_server/local_stream_server.dart';
import '../sequential/piece_priority_calculator.dart';
import '../sequential/stream_window_manager.dart';

class TorrentEngineRepositoryImpl implements TorrentEngineRepository {
  final TorrentEngine engine;
  final LocalStreamServer server;
  final StreamWindowManager windowManager;
  final CacheManager cacheManager;

  final StreamController<StreamState> _stateController =
      StreamController<StreamState>.broadcast();
  final StreamController<StreamTelemetry> _telemetryController =
      StreamController<StreamTelemetry>.broadcast();

  StreamSubscription<StreamTelemetry>? _engineTelemetrySubscription;
  StreamSubscription<Set<int>>? _pieceSubscription;

  TorrentInfo? _activeTorrent;
  int? _activeFileIndex;
  PiecePriorityCalculator? _activeCalc;
  String? _activeSessionUrl;
  bool _isDisposed = false;

  int? get activeFileIndex => _activeFileIndex;
  TorrentInfo? get activeTorrent => _activeTorrent;

  TorrentEngineRepositoryImpl({
    required this.engine,
    required this.server,
    required this.windowManager,
    required this.cacheManager,
  }) {
    _stateController.add(const StreamStateIdle());
  }

  @override
  Stream<StreamState> get stateStream => _stateController.stream;

  @override
  Stream<StreamTelemetry> get telemetryStream => _telemetryController.stream;

  @override
  Future<TorrentInfo> resolveMetadata(
    String uriOrPath, {
    Duration timeout = AppConstants.metadataTimeout,
  }) async {
    _stateController.add(
      StreamStateResolving(infoHash: '', elapsed: Duration.zero),
    );

    try {
      final info = await engine.resolveMetadata(uriOrPath, timeout: timeout);
      AppLogger.info('Resolved metadata for "${info.name}" (${info.totalBytes} bytes)');
      return info;
    } catch (e, st) {
      final failure = e is AppFailure ? e : TorrentEngineFailure('Failed to resolve metadata: $e', e);
      _stateController.add(StreamStateError(failure));
      AppLogger.error('Metadata resolution failed', e, st);
      rethrow;
    }
  }

  @override
  Future<String> startStreaming({
    required TorrentInfo torrent,
    required int fileIndex,
  }) async {
    _activeTorrent = torrent;
    _activeFileIndex = fileIndex;

    final file = torrent.files.firstWhere(
      (f) => f.index == fileIndex,
      orElse: () => throw TorrentEngineFailure('File index $fileIndex not found in torrent'),
    );

    _activeCalc = PiecePriorityCalculator(
      pieceLength: torrent.pieceLength,
      pieceCount: torrent.pieceCount,
      fileOffset: file.offset,
      fileLength: file.length,
    );

    windowManager.reset();

    // Start embedded HTTP server if not running
    if (!server.isRunning) {
      await server.start();
    }

    // Register stream with local server
    _activeSessionUrl = server.registerSession(
      infoHash: torrent.infoHash,
      fileIndex: file.index,
      fileName: file.fileName,
      fileOffset: file.offset,
      fileLength: file.length,
      priorityCalc: _activeCalc!,
      windowManager: windowManager,
    );

    _stateController.add(
      const StreamStateBuffering(
        progress: 0.0,
        downloadedBytes: 0,
        requiredBytes: AppConstants.defaultReadyThresholdBytes,
        downloadSpeedBytesPerSec: 0,
        activePeers: 0,
      ),
    );

    // Forward engine telemetry
    await _engineTelemetrySubscription?.cancel();
    _engineTelemetrySubscription = engine.getTelemetryStream(torrent.infoHash).listen(
      (telemetry) {
        if (!_isDisposed && !_telemetryController.isClosed) {
          _telemetryController.add(telemetry);
        }
      },
    );

    // Monitor piece arrivals to trigger Ready state
    await _pieceSubscription?.cancel();
    _pieceSubscription = windowManager.onPieceUpdates.listen((downloaded) {
      final calc = _activeCalc;
      if (calc != null && windowManager.isReadyToPlay(calc)) {
        _stateController.add(
          StreamStateReady(
            streamUrl: _activeSessionUrl!,
            totalLength: file.length,
          ),
        );
      }
    });

    // Start engine sequential session
    await engine.startSession(
      infoHash: torrent.infoHash,
      fileIndex: fileIndex,
      priorityCalc: _activeCalc!,
    );

    return _activeSessionUrl!;
  }

  @override
  Future<void> seek(int byteOffset) async {
    final torrent = _activeTorrent;
    final calc = _activeCalc;
    if (torrent == null || calc == null) return;

    windowManager.updatePlayhead(byteOffset);
    await engine.updatePlayhead(torrent.infoHash, byteOffset);

    // Check if new window is already downloaded
    if (!windowManager.isReadyToPlay(calc)) {
      _stateController.add(
        const StreamStateBuffering(
          progress: 0.0,
          downloadedBytes: 0,
          requiredBytes: AppConstants.urgentWindowBytes,
          downloadSpeedBytesPerSec: 0,
          activePeers: 0,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    final torrent = _activeTorrent;
    if (torrent != null) {
      await engine.pause(torrent.infoHash);
      _stateController.add(const StreamStatePaused());
    }
  }

  @override
  Future<void> resume() async {
    final torrent = _activeTorrent;
    if (torrent != null) {
      await engine.resume(torrent.infoHash);
      _stateController.add(const StreamStatePlaying());
    }
  }

  @override
  Future<void> stop() async {
    final torrent = _activeTorrent;
    if (torrent != null) {
      await engine.stop(torrent.infoHash);
      await cacheManager.cleanSession(torrent.infoHash);
    }

    await _engineTelemetrySubscription?.cancel();
    await _pieceSubscription?.cancel();
    _activeTorrent = null;
    _activeFileIndex = null;
    _activeCalc = null;
    _activeSessionUrl = null;

    _stateController.add(const StreamStateEnded());
  }

  void dispose() {
    _isDisposed = true;
    _engineTelemetrySubscription?.cancel();
    _pieceSubscription?.cancel();
    _stateController.close();
    _telemetryController.close();
  }
}
