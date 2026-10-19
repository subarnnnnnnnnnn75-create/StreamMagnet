import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/core/errors/failures.dart';
import 'package:stream_magnet/data/sequential/piece_priority_calculator.dart';
import 'package:stream_magnet/data/sequential/stream_window_manager.dart';

void main() {
  group('StreamWindowManager', () {
    const pieceLength = 1024 * 1024; // 1 MB
    late PiecePriorityCalculator calc;
    late StreamWindowManager windowManager;

    setUp(() {
      calc = PiecePriorityCalculator(
        pieceLength: pieceLength,
        pieceCount: 50,
        fileOffset: 0,
        fileLength: 50 * pieceLength,
        urgentWindowBytes: 4 * pieceLength,
        headerPiecesCount: 2,
        tailPiecesCount: 2,
      );
      windowManager = StreamWindowManager(
        readyThresholdBytes: 3 * pieceLength, // 3 MB initial threshold
      );
    });

    tearDown(() {
      windowManager.dispose();
    });

    test('isReadyToPlay returns false initially and true once threshold is satisfied', () {
      expect(windowManager.isReadyToPlay(calc), isFalse);

      // Download header pieces (pieces 0 and 1)
      windowManager.onPieceDownloaded(0);
      windowManager.onPieceDownloaded(1);

      // Not ready yet (needs initial buffer: pieces 0, 1, 2)
      expect(windowManager.isReadyToPlay(calc), isFalse);

      // Download piece 2 (satisfies 3 MB initial buffer)
      windowManager.onPieceDownloaded(2);

      expect(windowManager.isReadyToPlay(calc), isTrue);
    });

    test('waitForPieces completes immediately if pieces already present', () async {
      windowManager.onPieceDownloaded(5);
      windowManager.onPieceDownloaded(6);

      // Should complete without awaiting or timing out
      await expectLater(
        windowManager.waitForPieces({5, 6}, timeout: const Duration(seconds: 1)),
        completes,
      );
    });

    test('waitForPieces suspends and resolves when missing pieces arrive', () async {
      final waitFuture = windowManager.waitForPieces(
        {10, 11},
        timeout: const Duration(seconds: 2),
      );

      // Verify future hasn't finished yet
      bool finished = false;
      waitFuture.then((_) => finished = true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(finished, isFalse);

      // Trigger arrivals
      windowManager.onPieceDownloaded(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(finished, isFalse);

      windowManager.onPieceDownloaded(11);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(finished, isTrue);

      await expectLater(waitFuture, completes);
    });

    test('waitForPieces throws DeadTorrentFailure on timeout', () async {
      await expectLater(
        windowManager.waitForPieces(
          {99},
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<DeadTorrentFailure>()),
      );
    });

    test('calculateBufferAheadBytes returns contiguous byte count', () {
      // At playhead 0, pieces 0, 1, 2 downloaded
      windowManager.onPieceDownloaded(0);
      windowManager.onPieceDownloaded(1);
      windowManager.onPieceDownloaded(2);
      // Piece 4 is downloaded but piece 3 is missing
      windowManager.onPieceDownloaded(4);

      final bufferBytes = windowManager.calculateBufferAheadBytes(calc);
      // Should count pieces 0, 1, 2 only = 3 MB
      expect(bufferBytes, 3 * pieceLength);
    });
  });
}
