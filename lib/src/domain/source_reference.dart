import 'source_date.dart';

class SourceReference {
  const SourceReference({
    required this.title,
    required this.url,
    this.siteName,
    this.publishedAt,
  });

  final String title;
  final String url;
  final String? siteName;
  final String? publishedAt;

  String? get publicationLabel =>
      publishedAt == null ? null : SourceDate.tryParse(publishedAt!)?.label;

  bool get isFile => {'file', 'content'}.contains(Uri.parse(url).scheme);
  String get domain =>
      isFile ? '本地文件' : Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '');
  String get label => isFile ? title : siteName ?? domain;

  static SourceReference? fromLocalLink(String target, String linkTitle) {
    final uri = Uri.tryParse(target);
    if (uri == null) return null;
    if (uri.scheme == 'content' && uri.host.isNotEmpty) {
      return SourceReference(
        title: linkTitle.isEmpty || linkTitle.contains('content://')
            ? '本地文件'
            : linkTitle,
        url: uri.toString(),
      );
    }
    if ((uri.scheme.isEmpty && uri.host.isEmpty && uri.path.startsWith('/')) ||
        (uri.scheme == 'file' &&
            (uri.host.isEmpty || uri.host == 'localhost'))) {
      if (!uri.path.startsWith('/') || uri.path.endsWith('/')) return null;
      return SourceReference(
        title: uri.pathSegments.last,
        url: Uri.file(Uri.decodeComponent(uri.path)).toString(),
      );
    }
    return null;
  }

  // Standard Markdown keeps citations readable in saved history and model context.
  String get markdown {
    final label = _escape(title);
    final target = url.replaceAll('<', '%3C').replaceAll('>', '%3E');
    final marker = siteName == null ? '来源' : '来源：${_escape(siteName!)}';
    return '[$label](<$target> "$marker")';
  }

  static String _escape(String value) => value
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAllMapped(RegExp(r'[\\\[\]"]'), (match) => '\\${match[0]}');
}
