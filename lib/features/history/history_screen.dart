import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../home/torrent_details_sheet.dart';
import '../providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final d = Duration(milliseconds: ms);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _resumeStream(Map<String, dynamic> item) async {
    final rawUri = item['raw_uri'] as String;
    final repo = ref.read(torrentRepositoryProvider);
    final info = await repo.resolveMetadata(rawUri);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TorrentDetailsSheet(
        torrent: info,
        onStream: (selectedFile) async {
          final streamUrl = await repo.startStreaming(
            torrent: info,
            fileIndex: selectedFile.index,
          );
          if (mounted) {
            context.push(
              '/player',
              extra: {
                'streamUrl': streamUrl,
                'title': selectedFile.fileName,
                'infoHash': info.infoHash,
                'fileIndex': selectedFile.index,
                'totalLength': selectedFile.length,
              },
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All History?'),
                  content: const Text('This will delete all saved stream history items.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorAccent,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await db.clearHistory();
                ref.invalidate(historyProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search history...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (items) {
                final filtered = items.where((item) {
                  final name = (item['name'] as String).toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No history records found',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final infoHash = item['info_hash'] as String;
                    final name = item['name'] as String;
                    final positionMs = (item['position_ms'] as num).toInt();
                    final durationMs = (item['duration_ms'] as num).toInt();

                    return Dismissible(
                      key: Key(infoHash),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.errorAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await db.deleteHistoryItem(infoHash);
                        ref.invalidate(historyProvider);
                      },
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryAccent,
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: durationMs > 0
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Resume: ${_formatDuration(positionMs)} / ${_formatDuration(durationMs)}',
                                    style: const TextStyle(
                                      color: AppTheme.primaryAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _resumeStream(item),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading history: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
