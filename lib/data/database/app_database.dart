import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/logging/app_logger.dart';

/// SQLite Database layer managing History, Favorites, Settings, and Resume Positions
class AppDatabase {
  static const String _dbName = 'stream_magnet.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. History table
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        info_hash TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        raw_uri TEXT NOT NULL,
        selected_file_index INTEGER NOT NULL,
        position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER NOT NULL
      )
    ''');

    // 2. Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        info_hash TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        magnet_uri TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 3. Resume positions table
    await db.execute('''
      CREATE TABLE resume_positions (
        info_hash TEXT NOT NULL,
        file_index INTEGER NOT NULL,
        position_ms INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (info_hash, file_index)
      )
    ''');

    // 4. Ad blocker allowlist
    await db.execute('''
      CREATE TABLE adblock_allowlist (
        domain TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    AppLogger.info('AppDatabase tables created successfully');
  }

  // --- History DAO ---
  Future<void> saveHistoryItem({
    required String infoHash,
    required String name,
    required String rawUri,
    required int selectedFileIndex,
    required int positionMs,
    required int durationMs,
  }) async {
    final db = await database;
    await db.insert(
      'history',
      {
        'info_hash': infoHash,
        'name': name,
        'raw_uri': rawUri,
        'selected_file_index': selectedFileIndex,
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'last_played_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHistory({String? query}) async {
    final db = await database;
    if (query != null && query.trim().isNotEmpty) {
      return await db.query(
        'history',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'last_played_at DESC',
      );
    }
    return await db.query('history', orderBy: 'last_played_at DESC');
  }

  Future<void> deleteHistoryItem(String infoHash) async {
    final db = await database;
    await db.delete('history', where: 'info_hash = ?', whereArgs: [infoHash]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  // --- Resume Positions DAO ---
  Future<void> saveResumePosition({
    required String infoHash,
    required int fileIndex,
    required int positionMs,
    required int durationMs,
  }) async {
    final db = await database;
    await db.insert(
      'resume_positions',
      {
        'info_hash': infoHash,
        'file_index': fileIndex,
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getResumePosition(String infoHash, int fileIndex) async {
    final db = await database;
    final results = await db.query(
      'resume_positions',
      where: 'info_hash = ? AND file_index = ?',
      whereArgs: [infoHash, fileIndex],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // --- Favorites DAO ---
  Future<void> addFavorite({
    required String infoHash,
    required String title,
    required String magnetUri,
  }) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'info_hash': infoHash,
        'title': title,
        'magnet_uri': magnetUri,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String infoHash) async {
    final db = await database;
    await db.delete('favorites', where: 'info_hash = ?', whereArgs: [infoHash]);
  }

  Future<bool> isFavorite(String infoHash) async {
    final db = await database;
    final res = await db.query('favorites', where: 'info_hash = ?', whereArgs: [infoHash]);
    return res.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.query('favorites', orderBy: 'created_at DESC');
  }

  // --- Adblock Allowlist ---
  Future<void> allowDomain(String domain) async {
    final db = await database;
    await db.insert(
      'adblock_allowlist',
      {
        'domain': domain.toLowerCase(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeAllowedDomain(String domain) async {
    final db = await database;
    await db.delete('adblock_allowlist', where: 'domain = ?', whereArgs: [domain.toLowerCase()]);
  }

  Future<bool> isDomainAllowed(String domain) async {
    final db = await database;
    final res = await db.query(
      'adblock_allowlist',
      where: 'domain = ?',
      whereArgs: [domain.toLowerCase()],
    );
    return res.isNotEmpty;
  }

  Future<List<String>> getAllowedDomains() async {
    final db = await database;
    final res = await db.query('adblock_allowlist');
    return res.map((r) => r['domain'] as String).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
