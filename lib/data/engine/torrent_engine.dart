import '../../core/constants/app_constants.dart';
import '../../domain/entities/piece_priority.dart';
import '../../domain/entities/stream_telemetry.dart';
import '../../domain/entities/torrent_info.dart';
import '../sequential/piece_priority_calculator.dart';

/// Abstract bridge interface for the underlying BitTorrent engine
abstract interface class TorrentEngine {
  /// Initializes the native engine (sets up session, DHT, PEX, LSD, connections)
  Future<void> initialize({required String cachePath});

  /// Resolves torrent metadata from a magnet link or .torrent file path
  Future<TorrentInfo> resolveMetadata(
    String magnetOrTorrentPath, {
    Duration timeout = AppConstants.metadataTimeout,
  });

  /// Starts a sequential streaming session for a selected file within the torrent
  Future<void> startSession({
    required String infoHash,
    required int fileIndex,
    required PiecePriorityCalculator priorityCalc,
  });

  /// Updates the playhead position in bytes, recalculating priorities and deadlines
  Future<void> updatePlayhead(String infoHash, int byteOffset);

  /// Sets the download priority of an individual piece
  Future<void> setPiecePriority(
    String infoHash,
    int pieceIndex,
    PiecePriority priority,
  );

  /// Sets an urgent deadline (in milliseconds) for a piece
  Future<void> setPieceDeadline(
    String infoHash,
    int pieceIndex,
    int deadlineMs,
  );

  /// Reads raw bytes of a downloaded piece from cache/memory
  Future<List<int>> readPiece(String infoHash, int pieceIndex);

  /// Reads a byte range [byteStart, byteEndExclusive] for the selected file
  Future<List<int>> readRange(
    String infoHash,
    int fileIndex,
    int byteStart,
    int byteEnd,
  );

  /// Emits real-time telemetry updates (speed, peers, buffer, piece map)
  Stream<StreamTelemetry> getTelemetryStream(String infoHash);

  /// Pauses downloading and seeding
  Future<void> pause(String infoHash);

  /// Resumes downloading and seeding
  Future<void> resume(String infoHash);

  /// Stops streaming session and cleans up temporary resources
  Future<void> stop(String infoHash);

  /// Disposes engine session and background threads
  Future<void> dispose();
}
