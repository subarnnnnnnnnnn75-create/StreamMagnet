/// Application-wide constants for StreamMagnet
class AppConstants {
  AppConstants._();

  // Network & Server
  static const String loopbackAddress = '127.0.0.1';
  static const Duration metadataTimeout = Duration(seconds: 60);
  static const Duration pieceWaitTimeout = Duration(seconds: 30);
  static const Duration defaultPollInterval = Duration(milliseconds: 500);

  // Streaming Buffer Defaults
  static const int urgentWindowBytes = 12 * 1024 * 1024; // 12 MB around playhead
  static const int defaultLookaheadBytes = 64 * 1024 * 1024; // 64 MB
  static const int minLookaheadBytes = 16 * 1024 * 1024; // 16 MB
  static const int maxLookaheadBytes = 128 * 1024 * 1024; // 128 MB

  // Header & Container Metadata Prioritization
  static const int headerPiecesCount = 4; // First 4 pieces
  static const int tailPiecesCount = 4; // Last 4 pieces (e.g. MP4 moov atoms / MKV cues)

  // Ready to Play Thresholds
  static const int defaultReadyThresholdBytes = 8 * 1024 * 1024; // 8 MB
  static const int minReadyThresholdBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxReadyThresholdBytes = 16 * 1024 * 1024; // 16 MB

  // Cache Defaults
  static const int defaultCacheCapBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  static const int minCacheCapBytes = 512 * 1024 * 1024; // 512 MB
  static const int maxCacheCapBytes = 16 * 1024 * 1024 * 1024; // 16 GB

  // Torrent Engine Tuning
  static const int defaultMaxConnections = 200;
  static const int defaultUploadLimitBytesPerSec = 50 * 1024; // 50 KB/s
  static const bool defaultStopSeedingOnPlaybackEnd = true;
  static const bool defaultWifiOnly = true;

  // Video Extensions
  static const Set<String> supportedVideoExtensions = {
    'mp4',
    'mkv',
    'webm',
    'avi',
    'mov',
    'm4v',
    'flv',
    'ts',
    'wmv',
  };

  // Subtitle Extensions
  static const Set<String> supportedSubtitleExtensions = {
    'srt',
    'vtt',
    'ass',
    'ssa',
    'sub',
  };
}
