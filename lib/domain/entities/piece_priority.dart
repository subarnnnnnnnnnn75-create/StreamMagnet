/// BitTorrent piece priority levels
enum PiecePriority {
  dontDownload(0),
  low(1),
  normal(4),
  high(6),
  urgent(7);

  final int rawValue;
  const PiecePriority(this.rawValue);

  static PiecePriority fromRaw(int value) {
    return PiecePriority.values.firstWhere(
      (p) => p.rawValue == value,
      orElse: () => PiecePriority.normal,
    );
  }
}
