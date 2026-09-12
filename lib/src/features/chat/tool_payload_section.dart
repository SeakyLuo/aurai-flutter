import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'copy_icon.dart';

class ToolPayloadSection extends StatelessWidget {
  const ToolPayloadSection({
    super.key,
    required this.title,
    required this.json,
    required this.missing,
  });

  final String title;
  final String? json;
  final String missing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = json == null ? null : jsonDecode(json!);
    final retained =
        !(value is Map && value['contentRetention'] == 'task_only');
    final canCopy = json != null && retained;
    final text = !retained
        ? '此结果仅在执行时使用，未保留内容'
        : json == null
        ? missing
        : const JsonEncoder.withIndent('  ').convert(value);
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canCopy)
                  Semantics(
                    button: true,
                    label: '复制$title',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('已复制$title')),
                          );
                        } on Object {
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('复制失败，请重试')),
                          );
                        }
                      },
                      child: SizedBox(
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const SizedBox.square(
                                dimension: 17,
                                child: FittedBox(child: CopyIcon()),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '复制',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ),
          const SizedBox(height: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff2c2c2c)
                  : const Color(0xfff6f6f6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _PayloadScroll(
              child: canCopy
                  ? _JsonCode(text: text)
                  : SelectableText(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.75,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayloadScroll extends StatefulWidget {
  const _PayloadScroll({required this.child});
  final Widget child;

  @override
  State<_PayloadScroll> createState() => _PayloadScrollState();
}

class _PayloadScrollState extends State<_PayloadScroll> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 308),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Scrollbar(
          controller: _scroll,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: _scroll,
            primary: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class _JsonCode extends StatelessWidget {
  const _JsonCode({required this.text});
  final String text;

  static final _tokens = RegExp(
    r'"(?:[^"\\]|\\.)*"|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
  );

  List<InlineSpan> _highlight(String line, ColorScheme colors, bool dark) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _tokens.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final isString = token.startsWith('"');
      final isKey =
          isString && line.substring(match.end).trimLeft().startsWith(':');
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: isKey
                ? (dark ? const Color(0xffaaaaaa) : const Color(0xff777777))
                : isString
                ? (dark ? const Color(0xffeeeeee) : const Color(0xff333333))
                : colors.onSurface,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lines = text.split('\n');
    final style = TextStyle(
      fontSize: 13,
      height: 1.75,
      fontFamily: 'monospace',
      color: colors.onSurface,
    );
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectionContainer.disabled(
                    child: SizedBox(
                      width: 14 + lines.length.toString().length * 8,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.right,
                          style: style.copyWith(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: .65,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: colors.onSurface.withValues(alpha: .10),
                          ),
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: _highlight(lines[index], colors, dark),
                        ),
                        style: style,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
