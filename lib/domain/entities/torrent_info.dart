import '../../core/constants/app_constants.dart';

/// Represents parsed and verified torrent metadata
class TorrentInfo {
  final String infoHash;
  final String name;
  final int totalBytes;
  final int pieceLength;
  final int pieceCount;
  final List<TorrentFileItem> files;
  final List<String> trackers;

  const TorrentInfo({
    required this.infoHash,
    required this.name,
    required this.totalBytes,
    required this.pieceLength,
    required this.pieceCount,
    required this.files,
    this.trackers = const [],
  });

  /// Automatically selects the largest playable video file
  TorrentFileItem? get defaultPlayableFile {
    final videoFiles = files.where((f) => f.isVideo).toList();
    if (videoFiles.isEmpty) return null;
    videoFiles.sort((a, b) => b.length.compareTo(a.length));
    return videoFiles.first;
  }

  TorrentInfo copyWithFiles(List<TorrentFileItem> newFiles) {
    return TorrentInfo(
      infoHash: infoHash,
      name: name,
      totalBytes: totalBytes,
      pieceLength: pieceLength,
      pieceCount: pieceCount,
      files: newFiles,
      trackers: trackers,
    );
  }
}

/// Represents an individual file within a torrent
class TorrentFileItem {
  final int index;
  final String path;
  final int length;
  final int offset;
  final bool isSelected;

  const TorrentFileItem({
    required this.index,
    required this.path,
    required this.length,
    required this.offset,
    this.isSelected = false,
  });

  String get fileName => path.split('/').last;

  String get fileExtension {
    final segments = fileName.split('.');
    return segments.length > 1 ? segments.last.toLowerCase() : '';
  }

  bool get isVideo => AppConstants.supportedVideoExtensions.contains(fileExtension);

  bool get isSubtitle => AppConstants.supportedSubtitleExtensions.contains(fileExtension);

  TorrentFileItem copyWith({
    int? index,
    String? path,
    int? length,
    int? offset,
    bool? isSelected,
  }) {
    return TorrentFileItem(
      index: index ?? this.index,
      path: path ?? this.path,
      length: length ?? this.length,
      offset: offset ?? this.offset,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
