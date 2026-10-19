import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _termsAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPage(
                    icon: Icons.flash_on_rounded,
                    title: 'Instant Torrent Streaming',
                    description:
                        'StreamMagnet downloads pieces sequentially right around your playhead. Start watching high-definition video in seconds without waiting for complete downloads.',
                  ),
                  _buildPage(
                    icon: Icons.shield_rounded,
                    title: 'Built-in Ad & Tracker Blocker',
                    description:
                        'Browse safely with our built-in blocker covering the in-app browser and network traffic. Keeps trackers, popups, and malicious redirects out of your way.',
                  ),
                  _buildLegalNoticePage(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppTheme.primaryAccent),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalNoticePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.warningAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gavel_rounded,
              size: 56,
              color: AppTheme.warningAccent,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Important Legal Notice',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Text(
            'StreamMagnet is a neutral protocol client and contains NO copyrighted content, indexers, or search engines.\n\nYou are solely responsible for ensuring you have the legal right or authorization to stream any content you supply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: CheckboxListTile(
              value: _termsAgreed,
              activeColor: AppTheme.primaryAccent,
              onChanged: (val) => setState(() => _termsAgreed = val ?? false),
              title: const Text(
                'I understand and accept full responsibility for the media I stream.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryAccent
                      : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_currentPage < 2)
            Row(
              children: [
                TextButton(
                  onPressed: () => _pageController.jumpToPage(2),
                  child: const Text('Skip'),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(140, 50),
                  ),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Next'),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: _termsAgreed
                  ? () async {
                      final settingsRepo = ref.read(settingsRepositoryProvider);
                      final current = await settingsRepo.loadSettings();
                      await settingsRepo.saveSettings(
                        current.copyWith(termsAccepted: true),
                      );
                      if (mounted) {
                        context.go('/home');
                      }
                    }
                  : null,
              child: const Text('Get Started'),
            ),
        ],
      ),
    );
  }
}
