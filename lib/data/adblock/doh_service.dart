import 'dart:convert';
import 'dart:io';
import '../../core/logging/app_logger.dart';
import 'content_blocker_rules.dart';

/// DNS-over-HTTPS (DoH) resolver with built-in ad/tracker blocklist
class DohService {
  static const String cloudflareEndpoint = 'https://cloudflare-dns.com/dns-query';

  final HttpClient _httpClient = HttpClient();

  /// Resolves a domain hostname to an IPv4 address using DNS-over-HTTPS
  /// Returns null or throws if blocked by blocklist or resolution fails
  Future<String?> resolve(String hostname) async {
    final cleanHost = hostname.trim().toLowerCase();

    // Check against ad and tracker blocklist
    if (ContentBlockerRules.matchesBlocklist(cleanHost)) {
      AppLogger.info('DoH: Blocked lookup for ad/tracker domain "$cleanHost"');
      return null;
    }

    try {
      final uri = Uri.parse(cloudflareEndpoint).replace(
        queryParameters: {
          'name': cleanHost,
          'type': 'A',
        },
      );

      final request = await _httpClient.getUrl(uri);
      request.headers.set('Accept', 'application/dns-json');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final answers = json['Answer'] as List?;
      if (answers != null && answers.isNotEmpty) {
        for (final answer in answers) {
          if (answer is Map && answer['type'] == 1) { // Type 1 = A record (IPv4)
            final ip = answer['data'] as String?;
            if (ip != null && ip.isNotEmpty) {
              return ip;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('DoH resolution failed for $cleanHost: $e');
    }

    return null;
  }

  void close() {
    _httpClient.close(force: true);
  }
}
