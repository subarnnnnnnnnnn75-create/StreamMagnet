import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_settings.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSizeStr = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final cacheManager = ref.read(cacheManagerProvider);
    final formatted = await cacheManager.getFormattedCacheSize();
    if (mounted) setState(() => _cacheSizeStr = formatted);
  }

  @override
  Widget build(BuildContext context) {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) => _buildSettingsList(context, settings, settingsRepo),
        loading: () => FutureBuilder<AppSettings>(
          future: settingsRepo.loadSettings(),
          builder: (context, snap) {
            if (snap.hasData) {
              return _buildSettingsList(context, snap.data!, settingsRepo);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    AppSettings settings,
    dynamic settingsRepo,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. STREAMING SECTION
        _buildSectionHeader('STREAMING ENGINE'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.wifi_rounded, color: AppTheme.primaryAccent),
                title: const Text('Wi-Fi Only Streaming'),
                subtitle: const Text('Prevents high cellular data usage'),
                value: settings.wifiOnly,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(wifiOnly: val));
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.upload_rounded, color: AppTheme.primaryAccent),
                title: const Text('Stop Seeding When Playback Ends'),
                subtitle: const Text('Preserves battery and bandwidth'),
                value: settings.stopSeedingOnPlaybackEnd,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(stopSeedingOnPlaybackEnd: val));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.speed_rounded, color: AppTheme.primaryAccent),
                title: const Text('Upload Limit'),
                subtitle: Text('${settings.uploadLimitBytesPerSec ~/ 1024} KB/s'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    value: (settings.uploadLimitBytesPerSec ~/ 1024).toDouble(),
                    min: 10,
                    max: 500,
                    divisions: 49,
                    onChanged: (v) {
                      settingsRepo.saveSettings(
                        settings.copyWith(uploadLimitBytesPerSec: v.toInt() * 1024),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage_rounded, color: AppTheme.primaryAccent),
                title: const Text('Streaming Cache Cap'),
                subtitle: Text('${settings.cacheCapBytes ~/ (1024 * 1024 * 1024)} GB (LRU Eviction)'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    value: (settings.cacheCapBytes ~/ (1024 * 1024 * 1024)).toDouble(),
                    min: 1,
                    max: 16,
                    divisions: 15,
                    onChanged: (v) {
                      settingsRepo.saveSettings(
                        settings.copyWith(
                          cacheCapBytes: v.toInt() * 1024 * 1024 * 1024,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. AD BLOCKER & PRIVACY SECTION
        _buildSectionHeader('CONTENT & AD BLOCKER'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shield_rounded, color: AppTheme.primaryAccent),
                title: const Text('In-App & Network Ad Blocker'),
                subtitle: const Text('Blocks trackers, popups, and redirects'),
                value: settings.adBlockerEnabled,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(adBlockerEnabled: val));
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.open_in_new_off_rounded, color: AppTheme.primaryAccent),
                title: const Text('Block Intrusive Popups'),
                subtitle: const Text('Prevents forced new windows without gesture'),
                value: settings.blockPopups,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(blockPopups: val));
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dns_rounded, color: AppTheme.primaryAccent),
                title: const Text('DNS-over-HTTPS (DoH)'),
                subtitle: const Text('Secure encrypted DNS with blocklist'),
                value: settings.dohEnabled,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(dohEnabled: val));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.analytics_rounded, color: AppTheme.primaryAccent),
                title: const Text('Lifetime Ads & Trackers Blocked'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${settings.lifetimeBlockedCount}',
                    style: const TextStyle(
                      color: AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. PLAYBACK SECTION
        _buildSectionHeader('MEDIA PLAYBACK'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.memory_rounded, color: AppTheme.primaryAccent),
                title: const Text('Hardware Decoding'),
                subtitle: const Text('Enable GPU acceleration with software fallback'),
                value: settings.hardwareDecoding,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(hardwareDecoding: val));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.subtitles_rounded, color: AppTheme.primaryAccent),
                title: const Text('Subtitle Font Size'),
                subtitle: Text('${settings.subtitleFontSize.toInt()} pt'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    value: settings.subtitleFontSize,
                    min: 12,
                    max: 32,
                    divisions: 10,
                    onChanged: (v) {
                      settingsRepo.saveSettings(settings.copyWith(subtitleFontSize: v));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. STORAGE & SECURITY SECTION
        _buildSectionHeader('STORAGE & SECURITY'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryAccent),
                title: const Text('Clear Temporary Cache'),
                subtitle: Text('Current cache usage: $_cacheSizeStr'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36),
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final cacheManager = ref.read(cacheManagerProvider);
                    await cacheManager.clearAllCache();
                    await _refreshCacheSize();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Cache cleared successfully')),
                      );
                    }
                  },
                  child: const Text('Clear'),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryAccent),
                title: const Text('Biometric App Lock'),
                subtitle: const Text('Require Face ID / Fingerprint on launch'),
                value: settings.biometricsLockEnabled,
                activeThumbColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  settingsRepo.saveSettings(settings.copyWith(biometricsLockEnabled: val));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. ABOUT SECTION
        _buildSectionHeader('ABOUT & LEGAL'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryAccent),
                title: const Text('StreamMagnet'),
                subtitle: const Text('Version 1.0.0 (Production Release)'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_rounded, color: AppTheme.primaryAccent),
                title: const Text('Terms of Use & Privacy Policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showTermsDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryAccent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Privacy'),
        content: const SingleChildScrollView(
          child: Text(
            'StreamMagnet is an open-source, neutral BitTorrent protocol streaming application.\n\n'
            '1. No Included Content: StreamMagnet does not host, index, or link to any content.\n'
            '2. User Responsibility: Users provide all magnet URIs or .torrent files and are solely responsible for ensuring lawful access.\n'
            '3. Privacy First: No user analytics, telemetry, or personal tracking are collected.\n'
            '4. Content Blocker: The built-in ad blocker operates locally on your device to protect your browsing privacy.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
