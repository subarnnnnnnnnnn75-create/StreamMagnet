import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../engine/torrent_engine.dart';
import '../sequential/piece_priority_calculator.dart';
import '../sequential/stream_window_manager.dart';

/// Configuration for an active stream served by [LocalStreamServer]
class StreamSessionConfig {
  final String sessionId;
  final String infoHash;
  final int fileIndex;
  final String fileName;
  final int fileOffset;
  final int fileLength;
  final String token;
  final PiecePriorityCalculator priorityCalc;
  final StreamWindowManager windowManager;

  const StreamSessionConfig({
    required this.sessionId,
    required this.infoHash,
    required this.fileIndex,
    required this.fileName,
    required this.fileOffset,
    required this.fileLength,
    required this.token,
    required this.priorityCalc,
    required this.windowManager,
  });

  String get mimeType {
    return lookupMimeType(fileName) ?? 'video/mp4';
  }
}

/// Embedded HTTP server on 127.0.0.1 serving media streams with full HTTP 206 Range support
class LocalStreamServer {
  HttpServer? _server;
  final Map<String, StreamSessionConfig> _activeSessions = {};
  final TorrentEngine engine;

  LocalStreamServer({required this.engine});

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  /// Starts the HTTP server on loopback 127.0.0.1 on an ephemeral port
  Future<int> start() async {
    if (_server != null) return _server!.port;

    final router = Router();
    router.add('GET', '/stream/<sessionId>', _handleStreamRequest);
    router.add('HEAD', '/stream/<sessionId>', _handleStreamRequest);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    // Bind strictly to loopback interface
    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0, // random ephemeral port
    );

    AppLogger.info('LocalStreamServer started at http://${_server!.address.host}:${_server!.port}');
    return _server!.port;
  }

  /// Registers a new streaming session and returns the secure URL
  String registerSession({
    required String infoHash,
    required int fileIndex,
    required String fileName,
    required int fileOffset,
    required int fileLength,
    required PiecePriorityCalculator priorityCalc,
    required StreamWindowManager windowManager,
  }) {
    final sessionId = const Uuid().v4();
    final token = const Uuid().v4().replaceAll('-', '');

    final config = StreamSessionConfig(
      sessionId: sessionId,
      infoHash: infoHash,
      fileIndex: fileIndex,
      fileName: fileName,
      fileOffset: fileOffset,
      fileLength: fileLength,
      token: token,
      priorityCalc: priorityCalc,
      windowManager: windowManager,
    );

    _activeSessions[sessionId] = config;

    final portNumber = _server?.port ?? 0;
    return 'http://${AppConstants.loopbackAddress}:$portNumber/stream/$sessionId?token=$token';
  }

  /// Unregisters an active stream session
  void unregisterSession(String sessionId) {
    _activeSessions.remove(sessionId);
  }

  Future<Response> _handleStreamRequest(Request request, String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      return Response.notFound('Stream session not found or expired');
    }

    // Verify session token
    final requestToken = request.url.queryParameters['token'];
    if (requestToken == null || requestToken != session.token) {
      return Response.forbidden('Forbidden: invalid or missing session token');
    }

    final isHead = request.method == 'HEAD';
    final fileLength = session.fileLength;
    final mimeType = session.mimeType;

    // Handle Range header if present
    final rangeHeader = request.headers['range'];

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final rangeSpec = rangeHeader.substring(6).trim();
      final parts = rangeSpec.split('-');

      int start = 0;
      int end = fileLength - 1;

      if (parts[0].isNotEmpty) {
        start = int.tryParse(parts[0]) ?? 0;
      }

      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]) ?? (fileLength - 1);
      }

      // Check if range is unsatisfiable
      if (start > end || start >= fileLength || start < 0) {
        return Response(
          416,
          headers: {
            'Content-Range': 'bytes */$fileLength',
            'Accept-Ranges': 'bytes',
          },
        );
      }

      end = min(end, fileLength - 1);
      final rangeLength = end - start + 1;

      if (isHead) {
        return Response(
          206,
          headers: {
            'Content-Type': mimeType,
            'Content-Length': rangeLength.toString(),
            'Content-Range': 'bytes $start-$end/$fileLength',
            'Accept-Ranges': 'bytes',
          },
        );
      }

      // Update playhead on seek
      await engine.updatePlayhead(session.infoHash, start);

      // Block response until pieces for the start of requested range are downloaded
      final initialWaitBytes = min(rangeLength, AppConstants.urgentWindowBytes);
      try {
        await session.windowManager.waitForByteRange(
          start,
          initialWaitBytes,
          session.priorityCalc,
        );
      } catch (e) {
        AppLogger.error('Failed or timed out waiting for byte range $start..$end', e);
        return Response.internalServerError(
          body: 'Timed out waiting for video pieces from swarm',
        );
      }

      // Stream the requested byte range in chunks
      final stream = _createChunkedByteStream(
        session: session,
        start: start,
        end: end,
      );

      return Response(
        206,
        body: stream,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': rangeLength.toString(),
          'Content-Range': 'bytes $start-$end/$fileLength',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    // Full content response (no Range header)
    if (isHead) {
      return Response.ok(
        '',
        headers: {
          'Content-Type': mimeType,
          'Content-Length': fileLength.toString(),
          'Accept-Ranges': 'bytes',
        },
      );
    }

    // Wait for initial threshold pieces
    try {
      final initialWaitBytes = min(fileLength, AppConstants.defaultReadyThresholdBytes);
      await session.windowManager.waitForByteRange(
        0,
        initialWaitBytes,
        session.priorityCalc,
      );
    } catch (e) {
      AppLogger.error('Timeout waiting for initial stream pieces', e);
      return Response.internalServerError(
        body: 'Timed out waiting for initial stream pieces',
      );
    }

    final stream = _createChunkedByteStream(
      session: session,
      start: 0,
      end: fileLength - 1,
    );

    return Response.ok(
      stream,
      headers: {
        'Content-Type': mimeType,
        'Content-Length': fileLength.toString(),
        'Accept-Ranges': 'bytes',
      },
    );
  }

  /// Streams data in 128 KB chunks, awaiting piece arrival dynamically
  Stream<List<int>> _createChunkedByteStream({
    required StreamSessionConfig session,
    required int start,
    required int end,
  }) async* {
    const chunkSize = 128 * 1024; // 128 KB chunks
    int currentPos = start;

    while (currentPos <= end) {
      final chunkEnd = min(currentPos + chunkSize - 1, end);
      final currentChunkLength = chunkEnd - currentPos + 1;

      // Ensure pieces for this chunk are downloaded
      await session.windowManager.waitForByteRange(
        currentPos,
        currentChunkLength,
        session.priorityCalc,
      );

      final chunkData = await engine.readRange(
        session.infoHash,
        session.fileIndex,
        currentPos,
        chunkEnd + 1,
      );

      yield chunkData;
      currentPos += chunkData.length;
    }
  }

  /// Stops the local HTTP server
  Future<void> stop() async {
    _activeSessions.clear();
    await _server?.close(force: true);
    _server = null;
    AppLogger.info('LocalStreamServer stopped');
  }
}
