import 'dart:convert';

import 'package:html/dom.dart';

import '../domain/source_date.dart';

String? webPublicationDate(Document document) {
  for (final node in document.querySelectorAll(
    'meta[property="article:published_time"], '
    'meta[itemprop="datePublished"], time[itemprop="datePublished"][datetime]',
  )) {
    final date = _date(
      node.attributes['content'] ?? node.attributes['datetime'],
    );
    if (date != null) return date;
  }
  for (final script in document.querySelectorAll(
    'script[type="application/ld+json"]',
  )) {
    final Object? data;
    try {
      data = jsonDecode(script.text);
    } on FormatException {
      continue;
    }
    final date = _articleDate(data);
    if (date != null) return date;
  }
  return null;
}

String? _articleDate(Object? data) {
  if (data is List) {
    for (final node in data) {
      final date = _articleDate(node);
      if (date != null) return date;
    }
  } else if (data is Map) {
    final type = data['@type'];
    final types = type is List ? type : [type];
    if (types.any(
      (type) => const {
        'Article',
        'NewsArticle',
        'BlogPosting',
        'Report',
        'ScholarlyArticle',
      }.contains(type),
    )) {
      final date = _date(data['datePublished']);
      if (date != null) return date;
    }
    return _articleDate(data['@graph']);
  }
  return null;
}

String? _date(Object? value) =>
    value is String && SourceDate.tryParse(value) != null ? value.trim() : null;
