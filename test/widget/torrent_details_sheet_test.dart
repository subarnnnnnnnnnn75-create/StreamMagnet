import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/domain/entities/torrent_info.dart';
import 'package:stream_magnet/features/home/torrent_details_sheet.dart';

void main() {
  group('TorrentDetailsSheet Widget Tests', () {
    testWidgets('renders torrent name, total files and allows file selection', (tester) async {
      final torrent = TorrentInfo(
        infoHash: '0123456789abcdef0123456789abcdef01234567',
        name: 'Big Buck Bunny (Blender Foundation)',
        totalBytes: 50 * 1024 * 1024,
        pieceLength: 1024 * 1024,
        pieceCount: 50,
        files: const [
          TorrentFileItem(
            index: 0,
            path: 'BigBuckBunny.mp4',
            length: 49 * 1024 * 1024,
            offset: 0,
          ),
          TorrentFileItem(
            index: 1,
            path: 'subs/English.srt',
            length: 1024 * 1024,
            offset: 49 * 1024 * 1024,
          ),
        ],
      );

      TorrentFileItem? streamedFile;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TorrentDetailsSheet(
              torrent: torrent,
              onStream: (selected) {
                streamedFile = selected;
              },
            ),
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('Big Buck Bunny (Blender Foundation)'), findsOneWidget);
      // Verify files list
      expect(find.text('BigBuckBunny.mp4'), findsOneWidget);
      expect(find.text('English.srt'), findsOneWidget);
      // Verify stream button
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Tap stream now
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(streamedFile, isNotNull);
      expect(streamedFile!.fileName, 'BigBuckBunny.mp4');
    });
  });
}
