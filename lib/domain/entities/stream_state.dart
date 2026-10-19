import '../../core/errors/failures.dart';

/// Sealed class representing the lifecycle state of a torrent stream
sealed class StreamState {
  const StreamState();
}

/// Idle or uninitialized
final class StreamStateIdle extends StreamState {
  const StreamStateIdle();
}

/// Resolving torrent metadata from the magnet or .torrent file
final class StreamStateResolving extends StreamState {
  final String infoHash;
  final Duration elapsed;
  const StreamStateResolving({required this.infoHash, required this.elapsed});
}

/// Buffering pieces required to start or resume playback
final class StreamStateBuffering extends StreamState {
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int requiredBytes;
  final double downloadSpeedBytesPerSec;
  final int activePeers;

  const StreamStateBuffering({
    required this.progress,
    required this.downloadedBytes,
    required this.requiredBytes,
    required this.downloadSpeedBytesPerSec,
    required this.activePeers,
  });
}

/// Stream is ready to play (header pieces + initial buffer satisfied)
final class StreamStateReady extends StreamState {
  final String streamUrl;
  final int totalLength;
  const StreamStateReady({required this.streamUrl, required this.totalLength});
}

/// Media player is actively playing
final class StreamStatePlaying extends StreamState {
  const StreamStatePlaying();
}

/// Playback paused by user or buffering
final class StreamStatePaused extends StreamState {
  const StreamStatePaused();
}

/// Terminal error encountered during streaming
final class StreamStateError extends StreamState {
  final AppFailure failure;
  const StreamStateError(this.failure);
}

/// Stream playback completed / ended
final class StreamStateEnded extends StreamState {
  const StreamStateEnded();
}
