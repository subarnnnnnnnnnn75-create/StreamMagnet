import '../../core/constants/app_constants.dart';
import '../entities/stream_state.dart';
import '../entities/stream_telemetry.dart';
import '../entities/torrent_info.dart';

/// Repository contract for orchestrating torrent streaming sessions
abstract interface class TorrentEngineRepository {
  /// Resolves torrent metadata from a magnet link or .torrent file
  Future<TorrentInfo> resolveMetadata(
    String uriOrPath, {
    Duration timeout = AppConstants.metadataTimeout,
  });

  /// Starts sequential streaming of the selected file and returns the local stream URL
  Future<String> startStreaming({
    required TorrentInfo torrent,
    required int fileIndex,
  });

  /// Seeks to a new byte offset in the streaming video
  Future<void> seek(int byteOffset);

  /// Pauses downloading and streaming
  Future<void> pause();

  /// Resumes downloading and streaming
  Future<void> resume();

  /// Stops current stream session and performs cleanup
  Future<void> stop();

  /// Stream of overall lifecycle states (Resolving, Buffering, Ready, Playing, Paused, Error)
  Stream<StreamState> get stateStream;

  /// Stream of real-time telemetry metrics
  Stream<StreamTelemetry> get telemetryStream;
}
