import 'dart:developer' as dev;

/// Centralized logger for StreamMagnet
class AppLogger {
  AppLogger._();

  static void info(String message, [String tag = 'StreamMagnet']) {
    dev.log(message, name: tag, level: 800);
  }

  static void debug(String message, [String tag = 'StreamMagnet']) {
    dev.log(message, name: tag, level: 500);
  }

  static void warning(String message, [String tag = 'StreamMagnet']) {
    dev.log('⚠️ $message', name: tag, level: 900);
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String tag = 'StreamMagnet',
  ]) {
    dev.log(
      '❌ $message',
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
