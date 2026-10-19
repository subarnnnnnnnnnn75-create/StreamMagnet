import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/data/sequential/piece_priority_calculator.dart';
import 'package:stream_magnet/domain/entities/piece_priority.dart';

void main() {
  group('PiecePriorityCalculator', () {
    const pieceLength = 1024 * 1024; // 1 MB pieces
    const totalPieces = 100;
    const fileOffset = 10 * pieceLength; // starts at piece 10
    const fileLength = 50 * pieceLength; // 50 MB file (pieces 10..59)

    late PiecePriorityCalculator calc;

    setUp(() {
      calc = PiecePriorityCalculator(
        pieceLength: pieceLength,
        pieceCount: totalPieces,
        fileOffset: fileOffset,
        fileLength: fileLength,
        urgentWindowBytes: 4 * pieceLength, // 4 MB urgent window
        lookaheadBytes: 8 * pieceLength, // 8 MB lookahead window
        headerPiecesCount: 2,
        tailPiecesCount: 2,
      );
    });

    test('calculates correct file start and end pieces', () {
      expect(calc.fileStartPiece, 10);
      expect(calc.fileEndPiece, 59);
    });

    test('prioritizes headers, tails, and urgent window on initial playback', () {
      final schedule = calc.computeSchedule(
        playheadByte: 0,
        isInitialPlayback: true,
      );

      // Headers: pieces 10 and 11
      expect(schedule.headerPieces, containsAll([10, 11]));
      // Tails: pieces 58 and 59
      expect(schedule.tailPieces, containsAll([58, 59]));
      // Urgent window (from playhead 0, 4 MB -> pieces 10, 11, 12, 13, 14)
      expect(schedule.urgentPieces, containsAll([10, 11, 12, 13, 14]));

      // Urgent pieces must have PiecePriority.urgent
      expect(schedule.priorities[10], PiecePriority.urgent);
      expect(schedule.priorities[11], PiecePriority.urgent);
      expect(schedule.priorities[12], PiecePriority.urgent);

      // Tail pieces outside urgent window must have PiecePriority.high
      expect(schedule.priorities[58], PiecePriority.high);
      expect(schedule.priorities[59], PiecePriority.high);

      // Lookahead pieces must have PiecePriority.normal
      expect(schedule.lookaheadPieces, containsAll([15, 16, 17, 18]));
      expect(schedule.priorities[15], PiecePriority.normal);

      // Remaining pieces must have PiecePriority.low
      expect(schedule.priorities[30], PiecePriority.low);

      // Deadlines must be assigned for initial headers, tails, and urgent pieces
      expect(schedule.deadlines.containsKey(10), isTrue);
      expect(schedule.deadlines.containsKey(58), isTrue);
    });

    test('recalculates priorities and shifts urgent window on seek', () {
      // Seek to byte 25 MB into the file (which is piece 10 + 25 = piece 35)
      final playheadByte = 25 * pieceLength;
      final schedule = calc.computeSchedule(
        playheadByte: playheadByte,
        isInitialPlayback: false,
      );

      // Urgent window should center around piece 35
      expect(schedule.urgentPieces, containsAll([35, 36, 37, 38, 39]));
      expect(schedule.priorities[35], PiecePriority.urgent);
      expect(schedule.priorities[36], PiecePriority.urgent);

      // Deadlines must be set for the new urgent pieces
      expect(schedule.deadlines.containsKey(35), isTrue);
      expect(schedule.deadlines[35]!, isPositive);
    });

    test('getPiecesForByteRange correctly maps byte range to piece indices', () {
      // Range: 2.5 MB to 5.5 MB within file
      final start = (2.5 * pieceLength).toInt();
      final length = 3 * pieceLength;

      // Absolute byte: 10 MB + 2.5 MB = 12.5 MB (piece 12)
      // Absolute end: 15.5 MB (piece 15)
      final pieces = calc.getPiecesForByteRange(start, length);
      expect(pieces, containsAll([12, 13, 14, 15]));
    });
  });
}
