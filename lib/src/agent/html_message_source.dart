import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// File sources use the same private workspace as Android AppShellJobs.
abstract final class HtmlMessageSource {
  static const maxBytes = 256 * 1024;
  static const schema = {
    'type': ['string', 'null'],
    'description':
        'UTF-8 .html/.htm file in the shell tool working directory (agent-shell). '
        'Use a relative path such as miniapps/game.html. Supply either html or '
        'sourcePath, never both. The file is copied into the message, not linked.',
  };

  static Future<Map<String, Object?>> resolve(
    Map<String, Object?> args, {
    required bool creating,
  }) async {
    final html = args['html'];
    final source = args['sourcePath'];
    if (html != null && source != null) {
      throw ArgumentError('html 和 sourcePath 只能提供一个');
    }
    if (source == null) {
      if (html == null && !creating) return args;
      if (html is! String) throw ArgumentError('请提供 html 或 sourcePath');
      _validate(html);
      return args;
    }
    if (source is! String || source.trim().isEmpty) {
      throw ArgumentError('sourcePath 必须是 HTML 文件路径');
    }
    if (!source.toLowerCase().endsWith('.html') &&
        !source.toLowerCase().endsWith('.htm')) {
      throw ArgumentError('sourcePath 只支持 .html 或 .htm 文件');
    }
    try {
      final support = await getApplicationSupportDirectory();
      final workspace = await Directory(
        '${support.path}/agent-shell',
      ).resolveSymbolicLinks();
      final file = File(source).isAbsolute
          ? File(source)
          : File('$workspace/$source');
      final path = await file.resolveSymbolicLinks();
      if (!path.startsWith('$workspace${Platform.pathSeparator}')) {
        throw ArgumentError('sourcePath 必须位于 shell 工作目录内');
      }
      if (await FileSystemEntity.type(path) != FileSystemEntityType.file) {
        throw ArgumentError('sourcePath 必须指向普通 HTML 文件');
      }
      final handle = await File(path).open();
      late final String content;
      try {
        if (await handle.length() > maxBytes) {
          throw ArgumentError('HTML 最多 256 KB');
        }
        final bytes = await handle.read(maxBytes + 1);
        if (bytes.length > maxBytes) throw ArgumentError('HTML 最多 256 KB');
        content = utf8.decode(bytes);
      } finally {
        await handle.close();
      }
      _validate(content);
      return {...args, 'html': content}..remove('sourcePath');
    } on FileSystemException catch (error) {
      throw StateError(
        '无法读取小程序文件：${error.osError?.message ?? error.message}。'
        '请先用 shell 在工作目录中写好文件，再发布。',
      );
    } on FormatException {
      throw ArgumentError('小程序文件必须使用有效的 UTF-8 编码');
    }
  }

  static void _validate(String html) {
    if (html.trim().isEmpty || utf8.encode(html).length > maxBytes) {
      throw ArgumentError('HTML 不能为空且最多 256 KB');
    }
  }
}
