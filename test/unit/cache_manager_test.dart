import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stream_magnet/data/cache/cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheManager', () {
    late Directory testTempDir;
    late CacheManager cacheManager;

    setUp(() async {
      testTempDir = await Directory.systemTemp.createTemp('stream_magnet_test_');
      cacheManager = CacheManager(
        maxCapBytes: 5 * 1024 * 1024,
        customBaseDirectory: testTempDir,
      );
      await cacheManager.initialize();
    });

    tearDown(() async {
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
      }
    });

    test('initializes and creates session directory', () async {
      final sessionDir = await cacheManager.getSessionDirectory('test_hash');
      expect(await sessionDir.exists(), isTrue);
      expect(sessionDir.path, contains('test_hash'));
    });

    test('cleanSession removes session directory when keepDownloadedData is false', () async {
      final sessionDir = await cacheManager.getSessionDirectory('session_to_delete');
      final dummyFile = File(p.join(sessionDir.path, '0.piece'));
      await dummyFile.writeAsBytes([1, 2, 3]);

      expect(await sessionDir.exists(), isTrue);
      await cacheManager.cleanSession('session_to_delete');
      expect(await sessionDir.exists(), isFalse);
    });

    test('clearAllCache removes all sessions and reports freed bytes', () async {
      final sessionDir = await cacheManager.getSessionDirectory('session_a');
      final dummyFile = File(p.join(sessionDir.path, 'data.bin'));
      await dummyFile.writeAsBytes(List.filled(1024, 0)); // 1 KB

      final freed = await cacheManager.clearAllCache();
      expect(freed, greaterThanOrEqualTo(1024));
    });
  });
}
