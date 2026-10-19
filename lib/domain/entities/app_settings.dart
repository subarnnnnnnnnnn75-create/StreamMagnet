import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// App-wide persistent settings entity
class AppSettings {
  // Streaming Settings
  final int readyThresholdBytes;
  final int cacheCapBytes;
  final bool wifiOnly;
  final int uploadLimitBytesPerSec;
  final bool stopSeedingOnPlaybackEnd;
  final bool keepDownloadedData;

  // Playback Settings
  final bool hardwareDecoding;
  final double defaultSpeed;
  final double subtitleFontSize;
  final int subtitleColorValue;
  final int subtitleBackgroundColorValue;

  // Ad Blocker Settings
  final bool adBlockerEnabled;
  final bool blockPopups;
  final bool dohEnabled;
  final int lifetimeBlockedCount;

  // Appearance & Privacy
  final ThemeMode themeMode;
  final bool biometricsLockEnabled;
  final bool termsAccepted;

  const AppSettings({
    this.readyThresholdBytes = AppConstants.defaultReadyThresholdBytes,
    this.cacheCapBytes = AppConstants.defaultCacheCapBytes,
    this.wifiOnly = AppConstants.defaultWifiOnly,
    this.uploadLimitBytesPerSec = AppConstants.defaultUploadLimitBytesPerSec,
    this.stopSeedingOnPlaybackEnd = AppConstants.defaultStopSeedingOnPlaybackEnd,
    this.keepDownloadedData = false,
    this.hardwareDecoding = true,
    this.defaultSpeed = 1.0,
    this.subtitleFontSize = 16.0,
    this.subtitleColorValue = 0xFFFFFFFF, // White
    this.subtitleBackgroundColorValue = 0x88000000, // Semi-transparent black
    this.adBlockerEnabled = true,
    this.blockPopups = true,
    this.dohEnabled = false,
    this.lifetimeBlockedCount = 0,
    this.themeMode = ThemeMode.dark,
    this.biometricsLockEnabled = false,
    this.termsAccepted = false,
  });

  AppSettings copyWith({
    int? readyThresholdBytes,
    int? cacheCapBytes,
    bool? wifiOnly,
    int? uploadLimitBytesPerSec,
    bool? stopSeedingOnPlaybackEnd,
    bool? keepDownloadedData,
    bool? hardwareDecoding,
    double? defaultSpeed,
    double? subtitleFontSize,
    int? subtitleColorValue,
    int? subtitleBackgroundColorValue,
    bool? adBlockerEnabled,
    bool? blockPopups,
    bool? dohEnabled,
    int? lifetimeBlockedCount,
    ThemeMode? themeMode,
    bool? biometricsLockEnabled,
    bool? termsAccepted,
  }) {
    return AppSettings(
      readyThresholdBytes: readyThresholdBytes ?? this.readyThresholdBytes,
      cacheCapBytes: cacheCapBytes ?? this.cacheCapBytes,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      uploadLimitBytesPerSec: uploadLimitBytesPerSec ?? this.uploadLimitBytesPerSec,
      stopSeedingOnPlaybackEnd: stopSeedingOnPlaybackEnd ?? this.stopSeedingOnPlaybackEnd,
      keepDownloadedData: keepDownloadedData ?? this.keepDownloadedData,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleColorValue: subtitleColorValue ?? this.subtitleColorValue,
      subtitleBackgroundColorValue:
          subtitleBackgroundColorValue ?? this.subtitleBackgroundColorValue,
      adBlockerEnabled: adBlockerEnabled ?? this.adBlockerEnabled,
      blockPopups: blockPopups ?? this.blockPopups,
      dohEnabled: dohEnabled ?? this.dohEnabled,
      lifetimeBlockedCount: lifetimeBlockedCount ?? this.lifetimeBlockedCount,
      themeMode: themeMode ?? this.themeMode,
      biometricsLockEnabled: biometricsLockEnabled ?? this.biometricsLockEnabled,
      termsAccepted: termsAccepted ?? this.termsAccepted,
    );
  }
}
