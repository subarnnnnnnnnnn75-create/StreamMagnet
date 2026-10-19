import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/data/engine/simulated_torrent_engine.dart';
import 'package:stream_magnet/data/http_server/local_stream_server.dart';
import 'package:stream_magnet/data/sequential/piece_priority_calculator.dart';
import 'package:stream_magnet/data/sequential/stream_window_manager.dart';

void main() {
  group('LocalStreamServer', () {
    late StreamWindowManager windowManager;
    late SimulatedTorrentEngine engine;
    late LocalStreamServer server;
    late PiecePriorityCalculator calc;
    late String streamUrl;
    const fileLength = 10 * 1024 * 1024; // 10 MB

    setUp(() async {
      windowManager = StreamWindowManager();
      engine = SimulatedTorrentEngine(windowManager: windowManager);
      await engine.initialize(cachePath: '');
      server = LocalStreamServer(engine: engine);
      await server.start();

      calc = PiecePriorityCalculator(
        pieceLength: 1024 * 1024,
        pieceCount: 10,
        fileOffset: 0,
        fileLength: fileLength,
      );

      // Pre-download all pieces for server testing so response won't block
      for (int i = 0; i < 10; i++) {
        windowManager.onPieceDownloaded(i);
      }

      await engine.startSession(
        infoHash: 'test_hash',
        fileIndex: 0,
        priorityCalc: calc,
      );

      streamUrl = server.registerSession(
        infoHash: 'test_hash',
        fileIndex: 0,
        fileName: 'sample_video.mp4',
        fileOffset: 0,
        fileLength: fileLength,
        priorityCalc: calc,
        windowManager: windowManager,
      );
    });

    tearDown(() async {
      await server.stop();
      await engine.dispose();
    });

    test('binds to loopback 127.0.0.1 and generates valid tokenized URL', () {
      expect(server.isRunning, isTrue);
      expect(server.port, isNotNull);
      expect(streamUrl, contains('127.0.0.1:${server.port}/stream/'));
      expect(streamUrl, contains('token='));
    });

    test('rejects requests without or with invalid token with 403 Forbidden', () async {
      final uriWithoutToken = Uri.parse(streamUrl).replace(queryParameters: {});
      final client = HttpClient();
      final request = await client.getUrl(uriWithoutToken);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.forbidden);
      client.close();
    });

    test('HEAD request returns 200 with Accept-Ranges and Content-Length', () async {
      final client = HttpClient();
      final request = await client.headUrl(Uri.parse(streamUrl));
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('accept-ranges'), 'bytes');
      expect(response.headers.value('content-length'), fileLength.toString());
      expect(response.headers.value('content-type'), 'video/mp4');
      client.close();
    });

    test('GET request with Range header returns 206 Partial Content', () async {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamUrl));
      request.headers.add('range', 'bytes=0-1023');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers.value('content-range'), 'bytes 0-1023/$fileLength');
      expect(response.headers.value('content-length'), '1024');
      expect(response.headers.value('accept-ranges'), 'bytes');

      final bodyBytes = await response.fold<List<int>>(
        [],
        (prev, elem) => prev..addAll(elem),
      );
      expect(bodyBytes.length, 1024);
      client.close();
    });

    test('GET request with out-of-bounds Range returns 416 Range Not Satisfiable', () async {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamUrl));
      request.headers.add('range', 'bytes=${fileLength + 5000}-');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.headers.value('content-range'), 'bytes */$fileLength');
      client.close();
    });
  });
}
