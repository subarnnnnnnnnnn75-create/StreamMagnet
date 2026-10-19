/// Real-time telemetry metrics emitted during torrent streaming
class StreamTelemetry {
  final double downloadSpeedBytesPerSec;
  final double uploadSpeedBytesPerSec;
  final int activePeers;
  final int seedCount;
  final double bufferAheadSeconds;
  final int bufferAheadBytes;
  final int totalBytes;
  final int downloadedBytes;
  final List<bool> pieceBitfield;
  final Duration? etaToReady;

  const StreamTelemetry({
    this.downloadSpeedBytesPerSec = 0.0,
    this.uploadSpeedBytesPerSec = 0.0,
    this.activePeers = 0,
    this.seedCount = 0,
    this.bufferAheadSeconds = 0.0,
    this.bufferAheadBytes = 0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.pieceBitfield = const [],
    this.etaToReady,
  });

  double get downloadSpeedKBps => downloadSpeedBytesPerSec / 1024;
  double get downloadSpeedMBps => downloadSpeedBytesPerSec / (1024 * 1024);
  double get uploadSpeedKBps => uploadSpeedBytesPerSec / 1024;

  double get progressPercentage {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  StreamTelemetry copyWith({
    double? downloadSpeedBytesPerSec,
    double? uploadSpeedBytesPerSec,
    int? activePeers,
    int? seedCount,
    double? bufferAheadSeconds,
    int? bufferAheadBytes,
    int? totalBytes,
    int? downloadedBytes,
    List<bool>? pieceBitfield,
    Duration? etaToReady,
  }) {
    return StreamTelemetry(
      downloadSpeedBytesPerSec: downloadSpeedBytesPerSec ?? this.downloadSpeedBytesPerSec,
      uploadSpeedBytesPerSec: uploadSpeedBytesPerSec ?? this.uploadSpeedBytesPerSec,
      activePeers: activePeers ?? this.activePeers,
      seedCount: seedCount ?? this.seedCount,
      bufferAheadSeconds: bufferAheadSeconds ?? this.bufferAheadSeconds,
      bufferAheadBytes: bufferAheadBytes ?? this.bufferAheadBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      pieceBitfield: pieceBitfield ?? this.pieceBitfield,
      etaToReady: etaToReady ?? this.etaToReady,
    );
  }
}
