import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';

/// Manages temporary cache storage, LRU eviction behind playhead, and session cleanup
class CacheManager {
  final int maxCapBytes;
  final bool keepDownloadedData;
  final Directory? customBaseDirectory;
  Directory? _cacheDir;

  CacheManager({
    this.maxCapBytes = AppConstants.defaultCacheCapBytes,
    this.keepDownloadedData = false,
    this.customBaseDirectory,
  });

  /// Initializes the cache directory and cleans stale sessions from previous runs
  Future<void> initialize() async {
    if (customBaseDirectory != null) {
      _cacheDir = Directory(p.join(customBaseDirectory!.path, 'stream_magnet_cache'));
    } else {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory(p.join(tempDir.path, 'stream_magnet_cache'));
    }

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    } else {
      // Clean up orphaned session data from previous crashes or unclosed sessions
      if (!keepDownloadedData) {
        await cleanStaleSessions();
      }
    }

    AppLogger.info('CacheManager initialized at ${_cacheDir!.path}');
  }

  Directory get cacheDirectory {
    if (_cacheDir == null) {
      throw StateError('CacheManager must be initialized before use');
    }
    return _cacheDir!;
  }

  /// Directory path for an active torrent session
  Future<Directory> getSessionDirectory(String infoHash) async {
    final sessionDir = Directory(p.join(cacheDirectory.path, infoHash));
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }

  /// Cleans up cache files for a completed or aborted streaming session
  Future<void> cleanSession(String infoHash) async {
    if (keepDownloadedData) {
      AppLogger.info('Preserving downloaded session data for $infoHash as configured');
      return;
    }

    try {
      final sessionDir = Directory(p.join(cacheDirectory.path, infoHash));
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
        AppLogger.info('Cleaned session cache for $infoHash');
      }
    } catch (e) {
      AppLogger.warning('Error cleaning session cache for $infoHash: $e');
    }
  }

  /// Cleans all stale session directories
  Future<int> cleanStaleSessions() async {
    int bytesFreed = 0;
    try {
      if (!await cacheDirectory.exists()) return 0;

      await for (final entity in cacheDirectory.list()) {
        if (entity is Directory) {
          bytesFreed += await _calculateDirectorySize(entity);
          await entity.delete(recursive: true);
        }
      }
      AppLogger.info('Cleaned stale cache, freed ${(bytesFreed / (1024 * 1024)).toStringAsFixed(1)} MB');
    } catch (e) {
      AppLogger.warning('Error cleaning stale sessions: $e');
    }
    return bytesFreed;
  }

  /// Clears the entire cache on user demand
  Future<int> clearAllCache() async {
    return cleanStaleSessions();
  }

  /// Calculates total current cache usage in bytes
  Future<int> getCacheSizeBytes() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0;
    return _calculateDirectorySize(_cacheDir!);
  }

  /// Formatted string representing cache usage
  Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSizeBytes();
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Performs LRU eviction of pieces behind the playhead if cache usage exceeds cap
  Future<void> evictPiecesBehindPlayhead({
    required String infoHash,
    required int currentPlayheadPiece,
    required Set<int> headerPieces,
    required Set<int> tailPieces,
  }) async {
    final currentUsage = await getCacheSizeBytes();
    if (currentUsage <= maxCapBytes) return;

    AppLogger.info(
      'Cache cap exceeded (${(currentUsage / (1024 * 1024)).toStringAsFixed(1)} MB > ${(maxCapBytes / (1024 * 1024)).toStringAsFixed(1)} MB). Evicting LRU pieces behind playhead...',
    );

    try {
      final sessionDir = await getSessionDirectory(infoHash);
      if (!await sessionDir.exists()) return;

      final files = await sessionDir.list().toList();
      final pieceFiles = files.whereType<File>().toList();

      // Never evict header pieces or tail pieces
      for (final file in pieceFiles) {
        final filename = p.basename(file.path);
        final pieceIndex = int.tryParse(filename.split('.').first);
        if (pieceIndex != null) {
          if (pieceIndex < currentPlayheadPiece &&
              !headerPieces.contains(pieceIndex) &&
              !tailPieces.contains(pieceIndex)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error during LRU eviction: $e');
    }
  }

  Future<int> _calculateDirectorySize(Directory dir) async {
    int total = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }
}
