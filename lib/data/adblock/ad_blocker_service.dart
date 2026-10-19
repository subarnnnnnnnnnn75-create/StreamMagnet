import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/repositories/settings_repository.dart';
import '../database/app_database.dart';
import 'content_blocker_rules.dart';

/// Service managing content blocking state, allowlists, and per-page metrics
class AdBlockerService {
  final AppDatabase db;
  final SettingsRepository settingsRepo;

  final Map<int, int> _tabBlockedCounts = {};
  final StreamController<Map<int, int>> _blockedCountController =
      StreamController<Map<int, int>>.broadcast();

  AdBlockerService({
    required this.db,
    required this.settingsRepo,
  });

  Stream<Map<int, int>> get blockedCountsStream => _blockedCountController.stream;

  int getBlockedCountForTab(int tabIndex) => _tabBlockedCounts[tabIndex] ?? 0;

  void resetTabCount(int tabIndex) {
    _tabBlockedCounts[tabIndex] = 0;
    _blockedCountController.add(Map.unmodifiable(_tabBlockedCounts));
  }

  void incrementBlockedForTab(int tabIndex) {
    _tabBlockedCounts[tabIndex] = (_tabBlockedCounts[tabIndex] ?? 0) + 1;
    _blockedCountController.add(Map.unmodifiable(_tabBlockedCounts));
    settingsRepo.incrementBlockedAdsCount(1);
  }

  Future<List<ContentBlocker>> getActiveBlockers() async {
    final settings = await settingsRepo.loadSettings();
    if (!settings.adBlockerEnabled) return const [];

    final allowed = await db.getAllowedDomains();
    return ContentBlockerRules.getCompiledRules(
      blockPopups: settings.blockPopups,
      allowlistedDomains: allowed.toSet(),
    );
  }

  Future<bool> isDomainAllowlisted(String host) async {
    return db.isDomainAllowed(host);
  }

  Future<void> toggleAllowlistDomain(String host) async {
    final isAllowed = await db.isDomainAllowed(host);
    if (isAllowed) {
      await db.removeAllowedDomain(host);
    } else {
      await db.allowDomain(host);
    }
  }

  void dispose() {
    _blockedCountController.close();
  }
}
