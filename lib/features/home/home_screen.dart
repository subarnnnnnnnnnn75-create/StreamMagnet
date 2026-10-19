import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bencode_parser.dart';
import '../../core/utils/magnet_parser.dart';
import '../../domain/entities/torrent_info.dart';
import '../providers.dart';
import 'torrent_details_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  String? _clipboardMagnet;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && MagnetParser.tryParse(text) != null) {
        if (mounted && text != _clipboardMagnet) {
          setState(() => _clipboardMagnet = text);
        }
      }
    } catch (_) {}
  }

  Future<void> _resolveAndShowDetails(String input) async {
    setState(() => _isResolving = true);

    try {
      final repo = ref.read(torrentRepositoryProvider);
      final TorrentInfo info;

      if (input.toLowerCase().startsWith('magnet:?')) {
        info = await repo.resolveMetadata(input);
      } else {
        // Assume file path
        final file = File(input);
        final bytes = await file.readAsBytes();
        final parsed = BencodeParser.parse(bytes);
        info = TorrentInfo(
          infoHash: parsed.infoHash,
          name: parsed.name,
          totalBytes: parsed.totalLength,
          pieceLength: parsed.pieceLength,
          pieceCount: parsed.pieceHashes.length,
          files: parsed.files
              .map(
                (f) => TorrentFileItem(
                  index: f.index,
                  path: f.path,
                  length: f.length,
                  offset: f.offset,
                ),
              )
              .toList(),
          trackers: parsed.trackers,
        );
      }

      if (!mounted) return;
      setState(() => _isResolving = false);

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

            // Save to history
            final db = ref.read(databaseProvider);
            await db.saveHistoryItem(
              infoHash: info.infoHash,
              name: selectedFile.fileName,
              rawUri: input,
              selectedFileIndex: selectedFile.index,
              positionMs: 0,
              durationMs: 0,
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve torrent: $e'),
          backgroundColor: AppTheme.errorAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickTorrentFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final filePath = files.first.path!;
        await _resolveAndShowDetails(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening .torrent file: $e'),
            backgroundColor: AppTheme.errorAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stream_rounded, color: AppTheme.primaryAccent, size: 24),
            ),
            const SizedBox(width: 10),
            const Text('StreamMagnet'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clipboard Magnet Banner
              if (_clipboardMagnet != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: AppTheme.primaryAccent),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Magnet detected in clipboard',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final magnet = _clipboardMagnet!;
                          setState(() => _clipboardMagnet = null);
                          _resolveAndShowDetails(magnet);
                        },
                        child: const Text('Stream'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _clipboardMagnet = null),
                      ),
                    ],
                  ),
                ),
              ],

              const Text(
                'Stream Torrent Video',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Paste any magnet link to start playing instantly without downloading the entire file.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Paste field
              TextField(
                controller: _inputController,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'magnet:?xt=urn:btih:...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_inputController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _inputController.clear()),
                        ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() => _inputController.text = data!.text!.trim());
                          }
                        },
                      ),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: _isResolving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_isResolving ? 'Resolving...' : 'Play Stream'),
                      onPressed: _isResolving || _inputController.text.trim().isEmpty
                          ? null
                          : () => _resolveAndShowDetails(_inputController.text.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Open File'),
                      onPressed: _isResolving ? null : _pickTorrentFile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Recent items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recently Played',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => context.go('/history'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              historyAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 40,
                            color: Colors.grey.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No recent streams yet',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.take(5).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final name = item['name'] as String;
                        final uri = item['raw_uri'] as String;

                        return InkWell(
                          onTap: () => _resolveAndShowDetails(uri),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: AppTheme.primaryAccent,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.history_rounded,
                                      size: 16,
                                      color: Colors.grey.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap to resume',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
