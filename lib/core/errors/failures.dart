/// Sealed class hierarchy for typed error handling throughout StreamMagnet
sealed class AppFailure implements Exception {
  final String message;
  final Object? cause;

  const AppFailure(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Magnet URI parsing errors
final class MagnetParseFailure extends AppFailure {
  const MagnetParseFailure(super.message, [super.cause]);
}

/// Torrent file parsing errors
final class TorrentFileParseFailure extends AppFailure {
  const TorrentFileParseFailure(super.message, [super.cause]);
}

/// Torrent metadata resolution timeout
final class MetadataTimeoutFailure extends AppFailure {
  const MetadataTimeoutFailure([
    super.message = 'Timed out while resolving torrent metadata. The swarm may be inactive or lack seeds.',
    super.cause,
  ]);
}

/// Dead torrent error (0 seeds after timeout)
final class DeadTorrentFailure extends AppFailure {
  const DeadTorrentFailure([
    super.message = 'No active seeds found for this torrent. Playback cannot proceed.',
    super.cause,
  ]);
}

/// HTTP Range request error
final class RangeNotSatisfiableFailure extends AppFailure {
  const RangeNotSatisfiableFailure([
    super.message = 'Requested HTTP byte range is not satisfiable for the selected file.',
    super.cause,
  ]);
}

/// Local storage full error
final class StorageFullFailure extends AppFailure {
  const StorageFullFailure([
    super.message = 'Device storage is full or the cache cap has been exceeded.',
    super.cause,
  ]);
}

/// Network connectivity failure
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Network connection was lost or Wi-Fi only restriction blocked streaming.',
    super.cause,
  ]);
}

/// Torrent engine internal failure
final class TorrentEngineFailure extends AppFailure {
  const TorrentEngineFailure(super.message, [super.cause]);
}

/// Video playback failure
final class PlaybackFailure extends AppFailure {
  const PlaybackFailure(super.message, [super.cause]);
}
