import 'dart:convert';
import 'dart:math' as math;

import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'web_http.dart';
import 'web_publication_date.dart';

List<Map<String, Object?>> searchResults(WebResponse response, int limit) {
  final document = parse(response.bytes);
  if (document.querySelector('#b_captcha, #b_captcha_container') != null) {
    throw const WebRequestException('搜索服务要求验证码，请稍后再试');
  }
  final rows = document.querySelectorAll('#b_results .b_algo');
  if (rows.isEmpty && document.querySelector('#b_results .b_no') == null) {
    throw const WebRequestException('搜索页面未返回可识别的结果，可能需要验证或页面格式已变化');
  }
  final results = <Map<String, Object?>>[];
  for (final row in rows.take(limit)) {
    final anchor = row.querySelector('h2 a');
    final href = anchor?.attributes['href'];
    if (anchor == null || href == null) continue;
    var url = response.url.resolve(href);
    if (url.host.endsWith('bing.com') && url.path == '/ck/a') {
      final encoded = url.queryParameters['u'];
      if (encoded == null || !encoded.startsWith('a1')) continue;
      url = Uri.parse(
        utf8.decode(
          base64Url.decode(base64Url.normalize(encoded.substring(2))),
        ),
      );
    }
    if (!{'http', 'https'}.contains(url.scheme)) continue;
    final snippet = row.querySelector('.b_caption p')?.text ?? '';
    final siteName = row.querySelector('.tptt')?.text.trim();
    results.add({
      'title': anchor.text.trim(),
      'url': url.toString(),
      if (siteName != null && siteName.isNotEmpty) 'siteName': siteName,
      'snippet': snippet.substring(0, math.min(snippet.length, 1200)),
    });
  }
  if (rows.isNotEmpty && results.isEmpty) {
    throw const WebRequestException('搜索结果链接无法解析');
  }
  return results;
}

Map<String, Object?> pageContent(
  WebResponse response,
  int start,
  int maxChars,
) {
  final document = parse(response.bytes);
  final title = document.querySelector('title')?.text.trim() ?? '';
  final publishedAt = webPublicationDate(document);
  final siteName = document
      .querySelector('meta[property="og:site_name"]')
      ?.attributes['content']
      ?.trim();
  for (final node in document.querySelectorAll(
    'script, style, noscript, nav, header, footer, svg, form, [hidden], [aria-hidden="true"]',
  )) {
    node.remove();
  }
  final root =
      document.querySelector('main, article, [role="main"]') ?? document.body!;
  final buffer = StringBuffer();
  _writeText(root, buffer);
  final text = response.mimeType == 'text/plain'
      ? utf8.decode(response.bytes)
      : buffer
            .toString()
            .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
            .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
            .trim();
  if (text.isEmpty) {
    throw const WebRequestException('未读取到网页正文，页面可能需要登录或运行 JavaScript');
  }
  if (start >= text.length) {
    throw WebRequestException('读取位置超出正文长度（${text.length} 字符）');
  }
  final end = math.min(start + maxChars, text.length);
  final links = <Map<String, String>>[];
  final seen = <String>{};
  for (final anchor in root.querySelectorAll('a[href]')) {
    final url = response.url.resolve(anchor.attributes['href']!);
    final label = anchor.text.trim();
    if (!{'http', 'https'}.contains(url.scheme) ||
        label.isEmpty ||
        !seen.add(url.toString()))
      continue;
    links.add({
      'title': label.substring(0, math.min(label.length, 200)),
      'url': url.toString(),
    });
    if (links.length == 20) break;
  }
  return {
    'url': response.url.toString(),
    'title': title,
    if (publishedAt != null) 'publishedAt': publishedAt,
    if (siteName != null && siteName.isNotEmpty) 'siteName': siteName,
    'text': text.substring(start, end),
    'totalChars': text.length,
    'startChar': start,
    'nextStartChar': end < text.length ? end : null,
    'truncated': end < text.length,
    'links': links,
    'retrievedAt': DateTime.now().toUtc().toIso8601String(),
  };
}

void _writeText(Node node, StringBuffer buffer) {
  if (node is Text) {
    buffer.write(node.data);
    return;
  }
  const blocks = {
    'p',
    'div',
    'section',
    'article',
    'main',
    'br',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'pre',
    'tr',
    'blockquote',
  };
  final block = node is Element && blocks.contains(node.localName);
  if (block) buffer.writeln();
  for (final child in node.nodes) {
    _writeText(child, buffer);
  }
  if (node is Element && {'td', 'th'}.contains(node.localName))
    buffer.write('\t');
  if (block) buffer.writeln();
}
