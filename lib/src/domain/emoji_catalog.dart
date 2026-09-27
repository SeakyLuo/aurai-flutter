import 'dart:convert';
import 'package:flutter/services.dart';
import 'quick_reply_option.dart';

const emojiCategoryLabels = [
  '笑脸与情感',
  '人物与身体',
  '动物与自然',
  '食物与饮料',
  '旅行与地点',
  '活动',
  '物品',
  '符号',
  '旗帜',
];

class EmojiEntry {
  EmojiEntry(List<dynamic> row)
    : emoji = row[0] as String,
      label = row[1] as String,
      search = '${row[0]} ${row[1]} ${row[2]}'.toLowerCase(),
      category = row[3] as int,
      base = row[4] as String;
  final String emoji, label, search, base;
  final int category;
  QuickReplyOption get option =>
      quickReplyOptionsByEmoji[emoji.replaceAll('\uFE0F', '')]!;
}

class EmojiCatalog {
  EmojiCatalog(this.entries) {
    for (final entry in entries) {
      byKey[entry.option.key] = entry;
      variants.putIfAbsent(entry.base, () => []).add(entry);
      if (entry.emoji == entry.base) categories[entry.category].add(entry);
    }
  }
  final List<EmojiEntry> entries;
  final byKey = <String, EmojiEntry>{};
  final variants = <String, List<EmojiEntry>>{};
  final categories = List.generate(9, (_) => <EmojiEntry>[]);
  static Future<EmojiCatalog>? _loading;
  static Future<EmojiCatalog> load() => _loading ??= _load();
  static Future<EmojiCatalog> _load() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/emoji/catalog.json'))
            as Map;
    return EmojiCatalog([
      for (final row in json['entries'] as List) EmojiEntry(row as List),
    ]);
  }

  List<EmojiEntry> search(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final matches = entries
        .where((entry) => words.every(entry.search.contains))
        .toList();
    return [
      ...matches.where((entry) => entry.label == query || entry.emoji == query),
      ...matches.where((entry) => entry.label != query && entry.emoji != query),
    ];
  }
}
