import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../errors/failures.dart';

/// Parsed metadata from a .torrent file
class ParsedTorrent {
  final String infoHash;
  final String name;
  final int totalLength;
  final int pieceLength;
  final List<String> pieceHashes;
  final List<ParsedTorrentFile> files;
  final List<String> trackers;
  final String? comment;
  final String? createdBy;
  final DateTime? creationDate;

  const ParsedTorrent({
    required this.infoHash,
    required this.name,
    required this.totalLength,
    required this.pieceLength,
    required this.pieceHashes,
    required this.files,
    this.trackers = const [],
    this.comment,
    this.createdBy,
    this.creationDate,
  });
}

/// File metadata within a multi-file or single-file torrent
class ParsedTorrentFile {
  final int index;
  final String path;
  final int length;
  final int offset;

  const ParsedTorrentFile({
    required this.index,
    required this.path,
    required this.length,
    required this.offset,
  });

  bool get isVideo {
    final ext = path.split('.').last.toLowerCase();
    return const {
      'mp4',
      'mkv',
      'webm',
      'avi',
      'mov',
      'm4v',
      'flv',
      'ts',
      'wmv',
    }.contains(ext);
  }
}

/// Pure Dart Bencode parser and decoder
class BencodeParser {
  final Uint8List _bytes;
  int _cursor = 0;

  BencodeParser(this._bytes);

  static ParsedTorrent parse(Uint8List bytes) {
    try {
      final parser = BencodeParser(bytes);
      final dynamic root = parser._decode();

      if (root is! Map) {
        throw const TorrentFileParseFailure('Root element of .torrent must be a dictionary');
      }

      final infoObj = root['info'];
      if (infoObj is! Map) {
        throw const TorrentFileParseFailure('Torrent missing "info" dictionary');
      }

      // Calculate SHA-1 of the raw info dictionary
      final infoRange = parser._findInfoRange(bytes);
      final rawInfoBytes = bytes.sublist(infoRange.start, infoRange.end);
      final infoHash = sha1.convert(rawInfoBytes).toString();

      final name = _decodeString(infoObj['name']) ?? 'Unnamed Torrent';
      final pieceLength = (infoObj['piece length'] as num?)?.toInt() ?? 0;
      final piecesBytes = infoObj['pieces'];

      final pieceHashes = <String>[];
      if (piecesBytes is Uint8List) {
        for (int i = 0; i < piecesBytes.length; i += 20) {
          if (i + 20 <= piecesBytes.length) {
            final slice = piecesBytes.sublist(i, i + 20);
            pieceHashes.add(slice.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
          }
        }
      }

      final files = <ParsedTorrentFile>[];
      int totalLength = 0;

      if (infoObj.containsKey('files')) {
        // Multi-file torrent
        final filesList = infoObj['files'] as List;
        int currentOffset = 0;
        for (int i = 0; i < filesList.length; i++) {
          final fileMap = filesList[i] as Map;
          final len = (fileMap['length'] as num).toInt();
          final pathSegments = (fileMap['path'] as List)
              .map((p) => _decodeString(p) ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          final filePath = pathSegments.join('/');

          files.add(
            ParsedTorrentFile(
              index: i,
              path: filePath,
              length: len,
              offset: currentOffset,
            ),
          );
          currentOffset += len;
        }
        totalLength = currentOffset;
      } else if (infoObj.containsKey('length')) {
        // Single-file torrent
        final len = (infoObj['length'] as num).toInt();
        totalLength = len;
        files.add(
          ParsedTorrentFile(
            index: 0,
            path: name,
            length: len,
            offset: 0,
          ),
        );
      }

      // Trackers
      final trackers = <String>[];
      final announce = _decodeString(root['announce']);
      if (announce != null && announce.isNotEmpty) {
        trackers.add(announce);
      }
      final announceList = root['announce-list'];
      if (announceList is List) {
        for (final tier in announceList) {
          if (tier is List) {
            for (final tr in tier) {
              final trStr = _decodeString(tr);
              if (trStr != null && trStr.isNotEmpty && !trackers.contains(trStr)) {
                trackers.add(trStr);
              }
            }
          }
        }
      }

      final comment = _decodeString(root['comment']);
      final createdBy = _decodeString(root['created by']);
      DateTime? creationDate;
      if (root['creation date'] is num) {
        creationDate = DateTime.fromMillisecondsSinceEpoch(
          (root['creation date'] as num).toInt() * 1000,
          isUtc: true,
        );
      }

      return ParsedTorrent(
        infoHash: infoHash,
        name: name,
        totalLength: totalLength,
        pieceLength: pieceLength,
        pieceHashes: pieceHashes,
        files: files,
        trackers: trackers,
        comment: comment,
        createdBy: createdBy,
        creationDate: creationDate,
      );
    } catch (e, st) {
      if (e is AppFailure) rethrow;
      throw TorrentFileParseFailure('Failed to parse .torrent file: $e', st);
    }
  }

  static String? _decodeString(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is Uint8List) {
      try {
        return utf8.decode(val);
      } catch (_) {
        return latin1.decode(val);
      }
    }
    return val.toString();
  }

  _InfoRange _findInfoRange(Uint8List bytes) {
    // Search for 4:info in the root dictionary
    final pattern = [0x34, 0x3a, 0x69, 0x6e, 0x66, 0x6f]; // "4:info"
    for (int i = 0; i < bytes.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        final start = i + pattern.length;
        final parser = BencodeParser(bytes).._cursor = start;
        parser._decode();
        final end = parser._cursor;
        return _InfoRange(start, end);
      }
    }
    throw const TorrentFileParseFailure('Could not find "info" dictionary range');
  }

  dynamic _decode() {
    if (_cursor >= _bytes.length) {
      throw const TorrentFileParseFailure('Unexpected end of bencoded input');
    }

    final char = _bytes[_cursor];

    if (char == 0x69) {
      // 'i' -> integer
      return _decodeInt();
    } else if (char == 0x6c) {
      // 'l' -> list
      return _decodeList();
    } else if (char == 0x64) {
      // 'd' -> dictionary
      return _decodeDict();
    } else if (char >= 0x30 && char <= 0x39) {
      // '0'..'9' -> byte string
      return _decodeBytes();
    } else {
      throw TorrentFileParseFailure(
        'Invalid bencode prefix byte: 0x${char.toRadixString(16)} at index $_cursor',
      );
    }
  }

  int _decodeInt() {
    _cursor++; // skip 'i'
    final start = _cursor;
    while (_cursor < _bytes.length && _bytes[_cursor] != 0x65) {
      _cursor++;
    }
    if (_cursor >= _bytes.length) {
      throw const TorrentFileParseFailure('Unterminated integer in bencode');
    }
    final str = ascii.decode(_bytes.sublist(start, _cursor));
    _cursor++; // skip 'e'
    return int.parse(str);
  }

  Uint8List _decodeBytes() {
    final colonIndex = _bytes.indexOf(0x3a, _cursor); // ':'
    if (colonIndex == -1) {
      throw const TorrentFileParseFailure('Missing colon in bencode byte string');
    }
    final lenStr = ascii.decode(_bytes.sublist(_cursor, colonIndex));
    final len = int.parse(lenStr);
    _cursor = colonIndex + 1;

    if (_cursor + len > _bytes.length) {
      throw const TorrentFileParseFailure('Byte string length exceeds buffer size');
    }

    final data = _bytes.sublist(_cursor, _cursor + len);
    _cursor += len;
    return data;
  }

  List<dynamic> _decodeList() {
    _cursor++; // skip 'l'
    final list = <dynamic>[];
    while (_cursor < _bytes.length && _bytes[_cursor] != 0x65) {
      list.add(_decode());
    }
    if (_cursor >= _bytes.length) {
      throw const TorrentFileParseFailure('Unterminated list in bencode');
    }
    _cursor++; // skip 'e'
    return list;
  }

  Map<String, dynamic> _decodeDict() {
    _cursor++; // skip 'd'
    final dict = <String, dynamic>{};
    while (_cursor < _bytes.length && _bytes[_cursor] != 0x65) {
      final keyBytes = _decodeBytes();
      final key = utf8.decode(keyBytes, allowMalformed: true);
      final value = _decode();
      dict[key] = value;
    }
    if (_cursor >= _bytes.length) {
      throw const TorrentFileParseFailure('Unterminated dictionary in bencode');
    }
    _cursor++; // skip 'e'
    return dict;
  }
}

class _InfoRange {
  final int start;
  final int end;
  _InfoRange(this.start, this.end);
}
