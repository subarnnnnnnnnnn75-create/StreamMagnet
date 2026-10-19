import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/logging/app_logger.dart';
import 'features/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit audio/video native plugins
  MediaKit.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Biometrics App Lock Check
  final biometricsEnabled = prefs.getBool('biometricsLockEnabled') ?? false;
  if (biometricsEnabled) {
    try {
      final auth = LocalAuthentication();
      final canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canAuthenticate) {
        final authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to unlock StreamMagnet',
          biometricOnly: true,
        );
        if (!authenticated) {
          // User cancelled or failed authentication
          return;
        }
      }
    } catch (e) {
      AppLogger.warning('Biometric authentication check skipped or failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const StreamMagnetApp(),
    ),
  );
}
