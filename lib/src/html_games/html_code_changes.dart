import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Stable application identity merges successive publications into one change.
Map<String, Object?> htmlCodeChanges(
  String appId,
  String title,
  String before,
  String after,
) {
  String hash(String text) => sha256.convert(utf8.encode(text)).toString();
  List<String>? lines(String text) {
    if (utf8.encode(text).length > 128 * 1024) return null;
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return [
      for (final match in RegExp(r'[^\n]*\n|[^\n]+$').allMatches(normalized))
        base64Encode(sha256.convert(utf8.encode(match.group(0)!)).bytes),
    ];
  }

  return {
    'fileChangesComplete': true,
    'fileChanges': [
      if (before != after)
        {
          'path': 'miniapps/$appId/index.html',
          'displayPath': '$title/index.html',
          'before': hash(before),
          'after': hash(after),
          'beforeLines': lines(before),
          'afterLines': lines(after),
        },
    ],
  };
}
