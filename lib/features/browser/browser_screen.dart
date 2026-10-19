import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/adblock/ad_blocker_service.dart';
import '../providers.dart';

class WebTabItem {
  final int id;
  String title;
  String url;
  InAppWebViewController? controller;
  double progress;
  int blockedCount;

  WebTabItem({
    required this.id,
    this.title = 'New Tab',
    this.url = 'https://duckduckgo.com',
    this.progress = 0,
    this.blockedCount = 0,
  });
}

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final List<WebTabItem> _tabs = [
    WebTabItem(id: 0, title: 'DuckDuckGo', url: 'https://duckduckgo.com'),
  ];
  int _activeTabIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  String? _detectedMagnet;
  int _nextTabId = 1;

  WebTabItem get _currentTab => _tabs[_activeTabIndex];

  @override
  void initState() {
    super.initState();
    _urlController.text = _currentTab.url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addNewTab() {
    if (_tabs.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 tabs allowed')),
      );
      return;
    }

    setState(() {
      _tabs.add(
        WebTabItem(
          id: _nextTabId++,
          title: 'New Tab',
          url: 'https://duckduckgo.com',
        ),
      );
      _activeTabIndex = _tabs.length - 1;
      _urlController.text = _currentTab.url;
      _detectedMagnet = null;
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) return;
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      _urlController.text = _currentTab.url;
      _detectedMagnet = null;
    });
  }

  void _navigateToUrl(String input) {
    var target = input.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      if (target.contains('.') && !target.contains(' ')) {
        target = 'https://$target';
      } else {
        target = 'https://duckduckgo.com/?q=${Uri.encodeComponent(target)}';
      }
    }

    _currentTab.controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(target)),
    );
  }

  Future<void> _scanPageForMagnets() async {
    final controller = _currentTab.controller;
    if (controller == null) return;

    try {
      final dynamic result = await controller.evaluateJavascript(
        source: '''
          (function() {
            var links = document.querySelectorAll('a[href^="magnet:?"]');
            if (links.length > 0) {
              return links[0].href;
            }
            return null;
          })();
        ''',
      );

      if (result != null && result is String && result.startsWith('magnet:?')) {
        if (mounted && _detectedMagnet != result) {
          setState(() => _detectedMagnet = result);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final adBlocker = ref.watch(adBlockerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: _urlController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search or enter address...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                onPressed: () => _navigateToUrl(_urlController.text),
              ),
            ),
            onSubmitted: _navigateToUrl,
          ),
        ),
        actions: [
          // Ad Blocker Shield Badge
          IconButton(
            tooltip: 'Content Blocker Details',
            icon: Badge(
              label: Text('${_currentTab.blockedCount}'),
              isLabelVisible: _currentTab.blockedCount > 0,
              backgroundColor: AppTheme.primaryAccent,
              child: const Icon(Icons.shield_rounded, color: AppTheme.primaryAccent),
            ),
            onPressed: () => _showShieldInfo(adBlocker),
          ),
          // Tab Manager
          IconButton(
            icon: Badge(
              label: Text('${_tabs.length}'),
              child: const Icon(Icons.tab_rounded),
            ),
            onPressed: _showTabSwitcher,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView for current tab
          IndexedStack(
            index: _activeTabIndex,
            children: _tabs.map((tab) {
              return InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(tab.url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                  safeBrowsingEnabled: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (controller) async {
                  tab.controller = controller;
                  final blockers = await adBlocker.getActiveBlockers();
                  final settings = InAppWebViewSettings(contentBlockers: blockers);
                  await controller.setSettings(settings: settings);
                },
                onLoadStart: (controller, url) {
                  if (url != null) {
                    setState(() {
                      tab.url = url.toString();
                      if (_currentTab.id == tab.id) {
                        _urlController.text = tab.url;
                        _detectedMagnet = null;
                      }
                    });
                  }
                },
                onLoadStop: (controller, url) async {
                  setState(() => tab.progress = 1.0);
                  await _scanPageForMagnets();
                },
                onProgressChanged: (controller, progress) {
                  setState(() => tab.progress = progress / 100);
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri != null && uri.scheme == 'magnet') {
                    // Send to player directly!
                    setState(() => _detectedMagnet = uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              );
            }).toList(),
          ),

          // Progress Bar
          if (_currentTab.progress < 1.0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _currentTab.progress,
                minHeight: 2,
                color: AppTheme.primaryAccent,
              ),
            ),

          // Magnet Detection Banner
          if (_detectedMagnet != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryAccent),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.movie_creation_rounded, color: AppTheme.primaryAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Video Magnet Detected!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(110, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        final magnet = _detectedMagnet!;
                        setState(() => _detectedMagnet = null);
                        context.go('/home?magnet=${Uri.encodeComponent(magnet)}');
                      },
                      child: const Text('Stream Now', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              onPressed: () => _currentTab.controller?.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => _currentTab.controller?.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => _currentTab.controller?.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 24),
              tooltip: 'New Tab',
              onPressed: _addNewTab,
            ),
          ],
        ),
      ),
    );
  }

  void _showShieldInfo(AdBlockerService adBlocker) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppTheme.primaryAccent, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Built-in Content Blocker',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'StreamMagnet automatically blocks intrusive ads, trackers, popups, and forced redirects across the browser and app network.',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.block_rounded, color: AppTheme.primaryAccent),
                  title: const Text('Blocked on this tab'),
                  trailing: Text(
                    '${_currentTab.blockedCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTabSwitcher() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Open Tabs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New Tab'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addNewTab();
                    },
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isCurrent = index == _activeTabIndex;

                  return ListTile(
                    leading: Icon(
                      Icons.web_rounded,
                      color: isCurrent ? AppTheme.primaryAccent : Colors.grey,
                    ),
                    title: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      tab.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _tabs.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _closeTab(index);
                            },
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _activeTabIndex = index;
                        _urlController.text = tab.url;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
