import 'package:flutter_test/flutter_test.dart';
import 'package:stream_magnet/core/errors/failures.dart';
import 'package:stream_magnet/core/utils/magnet_parser.dart';

void main() {
  group('MagnetParser', () {
    test('parses valid 40-character hex info hash with display name and trackers', () {
      const magnet =
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567'
          '&dn=Big%20Buck%20Bunny'
          '&tr=udp%3A%2F%2Ftracker.example.com%3A1337%2Fannounce'
          '&tr=http%3A%2F%2Ftracker2.example.com%2Fannounce'
          '&ws=https%3A%2F%2Fmirror.example.com%2Fvideo.mp4';

      final result = MagnetParser.parse(magnet);

      expect(result.infoHash, '0123456789abcdef0123456789abcdef01234567');
      expect(result.displayName, 'Big Buck Bunny');
      expect(result.trackers.length, 2);
      expect(result.trackers[0], 'udp://tracker.example.com:1337/announce');
      expect(result.trackers[1], 'http://tracker2.example.com/announce');
      expect(result.webSeeds.length, 1);
      expect(result.webSeeds[0], 'https://mirror.example.com/video.mp4');
    });

    test('parses and converts 32-character base32 info hash to lowercase hex', () {
      // Base32 for 20 bytes
      // e.g., 'MFRGGZDFMY=======' is Base32 for 'abcde'
      // Standard 32-char RFC4648 Base32: 'NBSWY3DPO5XXE33NVACA===='
      // 32-char Base32: 'AA33BB44CC55DD66EE77FF88GG99HH00' (valid chars A-Z, 2-7)
      // 'JBSWY3DPEBLW64TMMQ======': 32 chars: 'JBSWY3DPEBLW64TMMQQQ222233334444'
      const base32 = 'JBSWY3DPEBLW64TMMQQQ222233334444';
      final magnet = 'magnet:?xt=urn:btih:$base32&dn=TestBase32';

      final result = MagnetParser.parse(magnet);
      expect(result.infoHash.length, 40);
      expect(RegExp(r'^[0-9a-f]{40}$').hasMatch(result.infoHash), isTrue);
      expect(result.displayName, 'TestBase32');
    });

    test('throws MagnetParseFailure for invalid URIs', () {
      expect(
        () => MagnetParser.parse('https://example.com/not-a-magnet'),
        throwsA(isA<MagnetParseFailure>()),
      );

      expect(
        () => MagnetParser.parse('magnet:?dn=NoHashTorrent'),
        throwsA(isA<MagnetParseFailure>()),
      );

      expect(
        () => MagnetParser.parse('magnet:?xt=urn:btih:too_short'),
        throwsA(isA<MagnetParseFailure>()),
      );
    });

    test('tryParse safely returns null on invalid input', () {
      expect(MagnetParser.tryParse(null), isNull);
      expect(MagnetParser.tryParse(''), isNull);
      expect(MagnetParser.tryParse('invalid'), isNull);
    });
  });
}
