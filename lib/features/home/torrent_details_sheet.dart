import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/torrent_info.dart';

class TorrentDetailsSheet extends StatefulWidget {
  final TorrentInfo torrent;
  final Function(TorrentFileItem selectedFile) onStream;

  const TorrentDetailsSheet({
    super.key,
    required this.torrent,
    required this.onStream,
  });

  @override
  State<TorrentDetailsSheet> createState() => _TorrentDetailsSheetState();
}

class _TorrentDetailsSheetState extends State<TorrentDetailsSheet> {
  late int _selectedFileIndex;

  @override
  void initState() {
    super.initState();
    final defaultFile = widget.torrent.defaultPlayableFile;
    _selectedFileIndex = defaultFile?.index ?? widget.torrent.files.first.index;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = widget.torrent.files.firstWhere(
      (f) => f.index == _selectedFileIndex,
      orElse: () => widget.torrent.files.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.movie_rounded, color: AppTheme.primaryAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.torrent.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${_formatBytes(widget.torrent.totalBytes)} • ${widget.torrent.files.length} files',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select File to Stream',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: widget.torrent.files.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = widget.torrent.files[index];
                final isSelected = file.index == _selectedFileIndex;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    file.isVideo
                        ? Icons.play_circle_fill_rounded
                        : (file.isSubtitle ? Icons.subtitles_rounded : Icons.insert_drive_file_rounded),
                    color: file.isVideo ? AppTheme.primaryAccent : Colors.grey,
                  ),
                  title: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: file.isVideo ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    _formatBytes(file.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  trailing: file.isVideo
                      ? Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? AppTheme.primaryAccent : Colors.grey,
                        )
                      : null,
                  onTap: file.isVideo
                      ? () => setState(() => _selectedFileIndex = file.index)
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onStream(selectedFile);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 24),
                const SizedBox(width: 8),
                Text('Stream Now (${_formatBytes(selectedFile.length)})'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
