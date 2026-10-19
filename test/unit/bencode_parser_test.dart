import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/core/errors/failures.dart';
import 'package:stream_magnet/core/utils/bencode_parser.dart';

void main() {
  group('BencodeParser', () {
    test('parses single-file .torrent metadata correctly', () {
      // Build a minimal single-file torrent:
      // d8:announce19:http://tr.test/ann4:infod6:lengthi10485760e4:name10:sample.mp412:piece lengthi1048576e6:pieces20:01234567890123456789ee
      final bencodeString =
          'd8:announce28:udp://tracker.example.com:80'
          '4:info'
          'd6:lengthi10485760e'
          '4:name10:sample.mp4'
          '12:piece lengthi1048576e'
          '6:pieces20:01234567890123456789ee';

      final bytes = Uint8List.fromList(utf8.encode(bencodeString));
      final torrent = BencodeParser.parse(bytes);

      expect(torrent.name, 'sample.mp4');
      expect(torrent.totalLength, 10485760);
      expect(torrent.pieceLength, 1048576);
      expect(torrent.files.length, 1);
      expect(torrent.files.first.path, 'sample.mp4');
      expect(torrent.files.first.isVideo, isTrue);
      expect(torrent.trackers, contains('udp://tracker.example.com:80'));
      expect(torrent.infoHash.length, 40);
    });

    test('parses multi-file .torrent structure and calculates file offsets', () {
      // Multi-file torrent:
      // info: { name: "Bundle", piece length: 524288, pieces: "...", files: [ { length: 500, path: ["sub.srt"] }, { length: 5000000, path: ["video.mkv"] } ] }
      final bencodeString =
          'd4:infod5:filesl'
          'd6:lengthi500e4:pathl7:sub.srtee'
          'd6:lengthi5000000e4:pathl9:video.mkvee'
          'e'
          '4:name6:Bundle'
          '12:piece lengthi524288e'
          '6:pieces20:01234567890123456789ee';

      final bytes = Uint8List.fromList(utf8.encode(bencodeString));
      final torrent = BencodeParser.parse(bytes);

      expect(torrent.name, 'Bundle');
      expect(torrent.files.length, 2);
      expect(torrent.files[0].path, 'sub.srt');
      expect(torrent.files[0].offset, 0);
      expect(torrent.files[0].length, 500);
      expect(torrent.files[0].isVideo, isFalse);

      expect(torrent.files[1].path, 'video.mkv');
      expect(torrent.files[1].offset, 500);
      expect(torrent.files[1].length, 5000000);
      expect(torrent.files[1].isVideo, isTrue);

      expect(torrent.totalLength, 5000500);
    });

    test('throws TorrentFileParseFailure on malformed bytes', () {
      final invalidBytes = Uint8List.fromList(utf8.encode('not-bencode'));
      expect(
        () => BencodeParser.parse(invalidBytes),
        throwsA(isA<TorrentFileParseFailure>()),
      );
    });
  });
}
