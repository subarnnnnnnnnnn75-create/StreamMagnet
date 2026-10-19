import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/piece_priority.dart';

/// Calculation result containing piece priorities and deadlines for the torrent engine
class PieceSchedule {
  /// Map of pieceIndex -> PiecePriority
  final Map<int, PiecePriority> priorities;

  /// Map of pieceIndex -> deadline in milliseconds (for set_piece_deadline)
  final Map<int, int> deadlines;

  /// Header piece indices required for metadata/container decoding
  final Set<int> headerPieces;

  /// Tail piece indices required for container indexes (e.g. MP4 moov at end or MKV cues)
  final Set<int> tailPieces;

  /// Indices of pieces in the urgent window right at the playhead
  final Set<int> urgentPieces;

  /// Indices of pieces in the lookahead buffer
  final Set<int> lookaheadPieces;

  /// Starting piece index of the selected file
  final int fileStartPiece;

  /// Ending piece index of the selected file (inclusive)
  final int fileEndPiece;

  const PieceSchedule({
    required this.priorities,
    required this.deadlines,
    required this.headerPieces,
    required this.tailPieces,
    required this.urgentPieces,
    required this.lookaheadPieces,
    required this.fileStartPiece,
    required this.fileEndPiece,
  });
}

/// Computes intelligent sequential piece priorities and deadlines around the playhead
class PiecePriorityCalculator {
  final int pieceLength;
  final int pieceCount;
  final int fileOffset;
  final int fileLength;
  final int urgentWindowBytes;
  final int lookaheadBytes;
  final int headerPiecesCount;
  final int tailPiecesCount;

  PiecePriorityCalculator({
    required this.pieceLength,
    required this.pieceCount,
    required this.fileOffset,
    required this.fileLength,
    this.urgentWindowBytes = AppConstants.urgentWindowBytes,
    this.lookaheadBytes = AppConstants.defaultLookaheadBytes,
    this.headerPiecesCount = AppConstants.headerPiecesCount,
    this.tailPiecesCount = AppConstants.tailPiecesCount,
  }) {
    assert(pieceLength > 0, 'pieceLength must be greater than 0');
    assert(fileLength > 0, 'fileLength must be greater than 0');
  }

  int get fileStartPiece => fileOffset ~/ pieceLength;

  int get fileEndPiece =>
      min(pieceCount - 1, (fileOffset + fileLength - 1) ~/ pieceLength);

  /// Computes piece schedule for a given playhead position in the file (0-indexed)
  PieceSchedule computeSchedule({
    required int playheadByte,
    bool isInitialPlayback = false,
  }) {
    final clampedPlayhead = playheadByte.clamp(0, fileLength - 1);
    final absolutePlayheadByte = fileOffset + clampedPlayhead;
    final currentPlayheadPiece = absolutePlayheadByte ~/ pieceLength;

    final priorities = <int, PiecePriority>{};
    final deadlines = <int, int>{};

    // 1. Identify Header & Tail pieces of the file
    final headerPieces = <int>{};
    final headerEnd = min(fileStartPiece + headerPiecesCount, fileEndPiece + 1);
    for (int p = fileStartPiece; p < headerEnd; p++) {
      headerPieces.add(p);
    }

    final tailPieces = <int>{};
    final tailStart = max(fileStartPiece, fileEndPiece - tailPiecesCount + 1);
    for (int p = tailStart; p <= fileEndPiece; p++) {
      tailPieces.add(p);
    }

    // 2. Identify Urgent window pieces around playhead
    final urgentPieces = <int>{};
    final urgentEndByte = absolutePlayheadByte + urgentWindowBytes;
    final urgentEndPiece = min(fileEndPiece, urgentEndByte ~/ pieceLength);
    for (int p = currentPlayheadPiece; p <= urgentEndPiece; p++) {
      urgentPieces.add(p);
    }

    // 3. Identify Lookahead buffer pieces
    final lookaheadPieces = <int>{};
    final lookaheadEndByte = urgentEndByte + lookaheadBytes;
    final lookaheadEndPiece = min(fileEndPiece, lookaheadEndByte ~/ pieceLength);
    for (int p = urgentEndPiece + 1; p <= lookaheadEndPiece; p++) {
      lookaheadPieces.add(p);
    }

    // 4. Assign priorities for all pieces of the selected file
    for (int p = fileStartPiece; p <= fileEndPiece; p++) {
      if (urgentPieces.contains(p)) {
        priorities[p] = PiecePriority.urgent;
      } else if (headerPieces.contains(p) || tailPieces.contains(p)) {
        priorities[p] = PiecePriority.high;
      } else if (lookaheadPieces.contains(p)) {
        priorities[p] = PiecePriority.normal;
      } else {
        priorities[p] = PiecePriority.low;
      }
    }

    // 5. Calculate deadlines in milliseconds for time-critical pieces
    // If starting initial playback, headers and initial urgent pieces have tight deadlines
    int deadlineMs = 500;
    if (isInitialPlayback) {
      for (final p in headerPieces) {
        deadlines[p] = deadlineMs;
        deadlineMs += 250;
      }
      for (final p in tailPieces) {
        deadlines[p] = deadlineMs;
        deadlineMs += 250;
      }
    }

    // Assign deadlines for urgent playhead window
    for (final p in urgentPieces) {
      if (!deadlines.containsKey(p)) {
        deadlines[p] = deadlineMs;
        deadlineMs += 500;
      }
    }

    return PieceSchedule(
      priorities: priorities,
      deadlines: deadlines,
      headerPieces: headerPieces,
      tailPieces: tailPieces,
      urgentPieces: urgentPieces,
      lookaheadPieces: lookaheadPieces,
      fileStartPiece: fileStartPiece,
      fileEndPiece: fileEndPiece,
    );
  }

  /// Calculates which pieces cover a specific byte range [startByte, endByte] within the file
  Set<int> getPiecesForByteRange(int startByte, int length) {
    if (length <= 0) return {};
    final absStart = fileOffset + startByte;
    final absEnd = absStart + length - 1;

    final startP = (absStart ~/ pieceLength).clamp(fileStartPiece, fileEndPiece);
    final endP = (absEnd ~/ pieceLength).clamp(fileStartPiece, fileEndPiece);

    final result = <int>{};
    for (int p = startP; p <= endP; p++) {
      result.add(p);
    }
    return result;
  }

  /// Converts a piece index to absolute byte boundaries [start, endExclusive]
  ({int start, int end}) getPieceByteRange(int pieceIndex) {
    final start = pieceIndex * pieceLength;
    final end = min(start + pieceLength, fileOffset + fileLength);
    return (start: start, end: end);
  }
}
