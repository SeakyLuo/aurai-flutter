import '../../app/glass_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../domain/error_message.dart';
import 'copy_icon.dart';

class MarkdownCodeBlockBuilder extends MarkdownElementBuilder {
  MarkdownCodeBlockBuilder({required this.compact});

  final bool compact;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children!.single as md.Element;
    final languageClass = code.attributes['class'];
    final language = languageClass == null
        ? '代码块'
        : languageClass.substring('language-'.length);
    return _MarkdownCodeBlock(
      code: element.textContent,
      compact: compact,
      language: language,
    );
  }
}

class _MarkdownCodeBlock extends StatelessWidget {
  const _MarkdownCodeBlock({
    required this.code,
    required this.compact,
    required this.language,
  });

  final String code;
  final String language;
  final bool compact;

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('代码已复制')));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('复制失败，请重试：${errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制代码',
                onPressed: () => _copy(context),
                icon: const CopyIcon(),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(32),
                  minimumSize: const Size.square(32),
                  padding: const EdgeInsets.all(6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            code.endsWith('\n') ? code.substring(0, code.length - 1) : code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: compact ? 13 : 14,
              height: compact ? 1.4 : 1.6,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
