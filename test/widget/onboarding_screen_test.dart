import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_magnet/features/onboarding/onboarding_screen.dart';
import 'package:stream_magnet/features/providers.dart';

void main() {
  group('OnboardingScreen Widget Tests', () {
    testWidgets('renders onboarding pages and terms acceptance', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      expect(find.text('Instant Torrent Streaming'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Built-in Ad & Tracker Blocker'), findsOneWidget);

      // Tap Next to legal notice page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Important Legal Notice'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}
