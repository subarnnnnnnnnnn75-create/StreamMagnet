import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Bundled ad/tracker blocking filters and Web Content Block rules
class ContentBlockerRules {
  ContentBlockerRules._();

  /// Known ad networks, telemetry trackers, malware and intrusive popup domains
  static const List<String> adAndTrackerDomains = [
    'doubleclick.net',
    'googleadservices.com',
    'googlesyndication.com',
    'criteo.com',
    'taboola.com',
    'outbrain.com',
    'popads.net',
    'popcash.net',
    'exoclick.com',
    'propellerads.com',
    'adcash.com',
    'adsterra.com',
    'adnxs.com',
    'scorecardresearch.com',
    'quantserve.com',
    'hotjar.com',
    'yandex.ru/ads',
    'zergnet.com',
    'coinhive.com',
    'adroll.com',
    'revcontent.com',
    'mgid.com',
    'adcolony.com',
    'applovin.com',
    'unityads.unity3d.com',
    'inmobi.com',
    'vungle.com',
    'chartboost.com',
  ];

  /// Compiles high-performance native ContentBlocker rules for flutter_inappwebview
  static List<ContentBlocker> getCompiledRules({
    bool blockPopups = true,
    Set<String> allowlistedDomains = const {},
  }) {
    final rules = <ContentBlocker>[];

    // 1. Block ad/tracker request patterns
    for (final domain in adAndTrackerDomains) {
      if (allowlistedDomains.contains(domain.toLowerCase())) continue;

      // Escape dots for regex
      final escaped = domain.replaceAll('.', r'\.');
      rules.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*$escaped.*',
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        ),
      );
    }

    // 2. Block intrusive popups and forced new windows
    if (blockPopups) {
      rules.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: r'.*(popads|popcash|exoclick|propellerads|adcash).*',
            resourceType: [
              ContentBlockerTriggerResourceType.SCRIPT,
              ContentBlockerTriggerResourceType.RAW,
            ],
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        ),
      );
    }

    return rules;
  }

  /// Fast regex-based domain check for network/DoH level blocking
  static bool matchesBlocklist(String urlOrHost) {
    final lower = urlOrHost.toLowerCase();
    for (final domain in adAndTrackerDomains) {
      if (lower.contains(domain)) return true;
    }
    return false;
  }
}
