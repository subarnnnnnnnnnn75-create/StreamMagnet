import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Stream<AppSettings> get settingsStream;
  Future<void> incrementBlockedAdsCount([int count = 1]);
}
