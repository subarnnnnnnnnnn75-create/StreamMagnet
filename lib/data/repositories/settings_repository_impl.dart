import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPreferences _prefs;
  final StreamController<AppSettings> _controller = StreamController<AppSettings>.broadcast();
  AppSettings? _currentSettings;

  SettingsRepositoryImpl(this._prefs);

  @override
  Stream<AppSettings> get settingsStream => _controller.stream;

  @override
  Future<AppSettings> loadSettings() async {
    if (_currentSettings != null) return _currentSettings!;

    final themeModeStr = _prefs.getString('themeMode') ?? 'dark';
    final themeMode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    _currentSettings = AppSettings(
      readyThresholdBytes: _prefs.getInt('readyThresholdBytes') ?? 8 * 1024 * 1024,
      cacheCapBytes: _prefs.getInt('cacheCapBytes') ?? 2 * 1024 * 1024 * 1024,
      wifiOnly: _prefs.getBool('wifiOnly') ?? true,
      uploadLimitBytesPerSec: _prefs.getInt('uploadLimitBytesPerSec') ?? 50 * 1024,
      stopSeedingOnPlaybackEnd: _prefs.getBool('stopSeedingOnPlaybackEnd') ?? true,
      keepDownloadedData: _prefs.getBool('keepDownloadedData') ?? false,
      hardwareDecoding: _prefs.getBool('hardwareDecoding') ?? true,
      defaultSpeed: _prefs.getDouble('defaultSpeed') ?? 1.0,
      subtitleFontSize: _prefs.getDouble('subtitleFontSize') ?? 16.0,
      subtitleColorValue: _prefs.getInt('subtitleColorValue') ?? 0xFFFFFFFF,
      subtitleBackgroundColorValue:
          _prefs.getInt('subtitleBackgroundColorValue') ?? 0x88000000,
      adBlockerEnabled: _prefs.getBool('adBlockerEnabled') ?? true,
      blockPopups: _prefs.getBool('blockPopups') ?? true,
      dohEnabled: _prefs.getBool('dohEnabled') ?? false,
      lifetimeBlockedCount: _prefs.getInt('lifetimeBlockedCount') ?? 0,
      themeMode: themeMode,
      biometricsLockEnabled: _prefs.getBool('biometricsLockEnabled') ?? false,
      termsAccepted: _prefs.getBool('termsAccepted') ?? false,
    );

    return _currentSettings!;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _currentSettings = settings;

    await _prefs.setInt('readyThresholdBytes', settings.readyThresholdBytes);
    await _prefs.setInt('cacheCapBytes', settings.cacheCapBytes);
    await _prefs.setBool('wifiOnly', settings.wifiOnly);
    await _prefs.setInt('uploadLimitBytesPerSec', settings.uploadLimitBytesPerSec);
    await _prefs.setBool('stopSeedingOnPlaybackEnd', settings.stopSeedingOnPlaybackEnd);
    await _prefs.setBool('keepDownloadedData', settings.keepDownloadedData);
    await _prefs.setBool('hardwareDecoding', settings.hardwareDecoding);
    await _prefs.setDouble('defaultSpeed', settings.defaultSpeed);
    await _prefs.setDouble('subtitleFontSize', settings.subtitleFontSize);
    await _prefs.setInt('subtitleColorValue', settings.subtitleColorValue);
    await _prefs.setInt('subtitleBackgroundColorValue', settings.subtitleBackgroundColorValue);
    await _prefs.setBool('adBlockerEnabled', settings.adBlockerEnabled);
    await _prefs.setBool('blockPopups', settings.blockPopups);
    await _prefs.setBool('dohEnabled', settings.dohEnabled);
    await _prefs.setInt('lifetimeBlockedCount', settings.lifetimeBlockedCount);
    await _prefs.setString('themeMode', settings.themeMode.name);
    await _prefs.setBool('biometricsLockEnabled', settings.biometricsLockEnabled);
    await _prefs.setBool('termsAccepted', settings.termsAccepted);

    _controller.add(settings);
  }

  @override
  Future<void> incrementBlockedAdsCount([int count = 1]) async {
    final current = await loadSettings();
    final updated = current.copyWith(
      lifetimeBlockedCount: current.lifetimeBlockedCount + count,
    );
    await saveSettings(updated);
  }
}
