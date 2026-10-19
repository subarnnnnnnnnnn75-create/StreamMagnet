import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/magnet_parser.dart';
import '../home/torrent_details_sheet.dart';
import '../providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  void _showAddFavoriteDialog() {
    final titleController = TextEditingController();
    final uriController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Favorite Magnet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title / Custom Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uriController,
              decoration: const InputDecoration(labelText: 'magnet:?xt=urn:btih:...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = uriController.text.trim();
              final title = titleController.text.trim();
              final parsed = MagnetParser.tryParse(uri);

              if (parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid magnet link')),
                );
                return;
              }

              final db = ref.read(databaseProvider);
              await db.addFavorite(
                infoHash: parsed.infoHash,
                title: title.isNotEmpty ? title : (parsed.displayName ?? 'Favorite Torrent'),
                magnetUri: uri,
              );

              ref.invalidate(favoritesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _playFavorite(String magnetUri) async {
    final repo = ref.read(torrentRepositoryProvider);
    final info = await repo.resolveMetadata(magnetUri);

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
    final favoritesAsync = ref.watch(favoritesProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Favorite',
            onPressed: _showAddFavoriteDialog,
          ),
        ],
      ),
      body: favoritesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No favorite magnets saved yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(180, 48),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Favorite'),
                    onPressed: _showAddFavoriteDialog,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final infoHash = item['info_hash'] as String;
              final title = item['title'] as String;
              final magnetUri = item['magnet_uri'] as String;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.secondaryAccent,
                    child: Icon(Icons.star_rounded, color: Colors.white),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    infoHash,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await db.removeFavorite(infoHash);
                      ref.invalidate(favoritesProvider);
                    },
                  ),
                  onTap: () => _playFavorite(magnetUri),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
