import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/adblock/ad_blocker_service.dart';
import '../data/cache/cache_manager.dart';
import '../data/database/app_database.dart';
import '../data/engine/platform_torrent_engine.dart';
import '../data/engine/simulated_torrent_engine.dart';
import '../data/engine/torrent_engine.dart';
import '../data/http_server/local_stream_server.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/torrent_engine_repository_impl.dart';
import '../data/sequential/stream_window_manager.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/stream_state.dart';
import '../domain/entities/stream_telemetry.dart';
import '../domain/repositories/settings_repository.dart';

// Database & Preferences
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

// Settings
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs);
});

final settingsProvider = StreamProvider<AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.settingsStream;
});

// Cache & Windows
final cacheManagerProvider = Provider<CacheManager>((ref) {
  final manager = CacheManager();
  manager.initialize();
  return manager;
});

final windowManagerProvider = Provider<StreamWindowManager>((ref) {
  final wm = StreamWindowManager();
  ref.onDispose(() => wm.dispose());
  return wm;
});

// Torrent Engine
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final wm = ref.watch(windowManagerProvider);

  // On Android/iOS use PlatformTorrentEngine; on other platforms or fallback use Simulated
  if (Platform.isAndroid || Platform.isIOS) {
    return PlatformTorrentEngine(windowManager: wm);
  }
  return SimulatedTorrentEngine(windowManager: wm);
});

// Local HTTP Server
final localStreamServerProvider = Provider<LocalStreamServer>((ref) {
  final engine = ref.watch(torrentEngineProvider);
  final server = LocalStreamServer(engine: engine);
  ref.onDispose(() => server.stop());
  return server;
});

// Torrent Repository
final torrentRepositoryProvider = Provider<TorrentEngineRepositoryImpl>((ref) {
  final engine = ref.watch(torrentEngineProvider);
  final server = ref.watch(localStreamServerProvider);
  final wm = ref.watch(windowManagerProvider);
  final cache = ref.watch(cacheManagerProvider);

  final repo = TorrentEngineRepositoryImpl(
    engine: engine,
    server: server,
    windowManager: wm,
    cacheManager: cache,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

// Telemetry & State Streams
final streamStateProvider = StreamProvider<StreamState>((ref) {
  final repo = ref.watch(torrentRepositoryProvider);
  return repo.stateStream;
});

final streamTelemetryProvider = StreamProvider<StreamTelemetry>((ref) {
  final repo = ref.watch(torrentRepositoryProvider);
  return repo.telemetryStream;
});

// Ad Blocker
final adBlockerServiceProvider = Provider<AdBlockerService>((ref) {
  final db = ref.watch(databaseProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final service = AdBlockerService(db: db, settingsRepo: settingsRepo);
  ref.onDispose(() => service.dispose());
  return service;
});

// History & Favorites
final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getHistory();
});

final favoritesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getFavorites();
});
