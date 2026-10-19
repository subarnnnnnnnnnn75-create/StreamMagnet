import 'dart:typed_data';
import '../errors/failures.dart';

/// Represents a parsed BitTorrent Magnet link
class MagnetUri {
  /// 40-character hexadecimal info hash (lowercase)
  final String infoHash;

  /// Display name if provided in magnet (dn)
  final String? displayName;

  /// List of tracker URLs (tr)
  final List<String> trackers;

  /// List of web seed URLs (ws)
  final List<String> webSeeds;

  /// Exact length in bytes if specified (xl)
  final int? exactLength;

  /// Raw original magnet URI
  final String rawUri;

  const MagnetUri({
    required this.infoHash,
    this.displayName,
    this.trackers = const [],
    this.webSeeds = const [],
    this.exactLength,
    required this.rawUri,
  });

  /// Canonical magnet link with trackers and display name
  String toCanonicalUri() {
    final buffer = StringBuffer('magnet:?xt=urn:btih:$infoHash');
    if (displayName != null && displayName!.isNotEmpty) {
      buffer.write('&dn=${Uri.encodeComponent(displayName!)}');
    }
    for (final tr in trackers) {
      buffer.write('&tr=${Uri.encodeComponent(tr)}');
    }
    for (final ws in webSeeds) {
      buffer.write('&ws=${Uri.encodeComponent(ws)}');
    }
    if (exactLength != null) {
      buffer.write('&xl=$exactLength');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MagnetUri &&
          runtimeType == other.runtimeType &&
          infoHash == other.infoHash;

  @override
  int get hashCode => infoHash.hashCode;

  @override
  String toString() =>
      'MagnetUri(infoHash: $infoHash, dn: $displayName, trackers: ${trackers.length})';
}

/// Utility for parsing and validating Magnet URIs
class MagnetParser {
  MagnetParser._();

  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Parses a magnet link string and returns a typed [MagnetUri].
  /// Throws [MagnetParseFailure] if the input is invalid.
  static MagnetUri parse(String rawInput) {
    final trimmed = rawInput.trim();
    if (!trimmed.toLowerCase().startsWith('magnet:?')) {
      throw const MagnetParseFailure(
        'Invalid magnet URI: string must begin with "magnet:?"',
      );
    }

    final queryString = trimmed.substring(8);
    final params = _parseQueryString(queryString);

    final xtList = params['xt'] ?? [];
    String? resolvedHash;

    for (final xt in xtList) {
      final lowerXt = xt.toLowerCase();
      if (lowerXt.startsWith('urn:btih:')) {
        final hashPart = xt.substring(9).trim();
        resolvedHash = _normalizeHash(hashPart);
        break;
      }
    }

    if (resolvedHash == null) {
      throw const MagnetParseFailure(
        'Missing or invalid "xt=urn:btih:" parameter in magnet URI',
      );
    }

    final dnList = params['dn'];
    final displayName = dnList != null && dnList.isNotEmpty ? dnList.first : null;

    final trackers = params['tr'] ?? [];
    final webSeeds = params['ws'] ?? [];

    int? exactLength;
    final xlList = params['xl'];
    if (xlList != null && xlList.isNotEmpty) {
      exactLength = int.tryParse(xlList.first);
    }

    return MagnetUri(
      infoHash: resolvedHash,
      displayName: displayName,
      trackers: List.unmodifiable(trackers),
      webSeeds: List.unmodifiable(webSeeds),
      exactLength: exactLength,
      rawUri: trimmed,
    );
  }

  /// Attempts to parse without throwing, returns null on error.
  static MagnetUri? tryParse(String? rawInput) {
    if (rawInput == null || rawInput.trim().isEmpty) return null;
    try {
      return parse(rawInput);
    } catch (_) {
      return null;
    }
  }

  /// Normalizes a 40-character hex or 32-character base32 info-hash into 40-character lowercase hex.
  static String _normalizeHash(String hash) {
    final clean = hash.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    // 40-char Hexadecimal
    if (clean.length == 40 && RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(clean)) {
      return clean.toLowerCase();
    }

    // 32-char Base32
    if (clean.length == 32 && RegExp(r'^[2-7a-zA-Z]{32}$').hasMatch(clean)) {
      final bytes = _decodeBase32(clean.toUpperCase());
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    throw MagnetParseFailure(
      'Invalid BitTorrent info-hash length or characters: "$hash" (expected 40 hex or 32 base32 chars)',
    );
  }

  /// Decodes RFC 4648 Base32 string to Uint8List
  static Uint8List _decodeBase32(String input) {
    int buffer = 0;
    int bitsLeft = 0;
    final output = <int>[];

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final val = _base32Alphabet.indexOf(char);
      if (val < 0) {
        throw MagnetParseFailure('Invalid Base32 character: $char');
      }

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return Uint8List.fromList(output);
  }

  /// Custom query string parser that preserves multiple values for keys like 'tr' and 'ws'
  static Map<String, List<String>> _parseQueryString(String query) {
    final result = <String, List<String>>{};
    final pairs = query.split('&');

    for (final pair in pairs) {
      if (pair.isEmpty) continue;
      final idx = pair.indexOf('=');
      String key;
      String value;

      if (idx == -1) {
        key = Uri.decodeQueryComponent(pair);
        value = '';
      } else {
        key = Uri.decodeQueryComponent(pair.substring(0, idx));
        value = Uri.decodeQueryComponent(pair.substring(idx + 1));
      }

      result.putIfAbsent(key, () => []).add(value);
    }

    return result;
  }
}
