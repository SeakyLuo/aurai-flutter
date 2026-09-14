import '../../domain/error_message.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'copy_icon.dart';

class ToolPayloadSection extends StatefulWidget {
  const ToolPayloadSection({
    super.key,
    required this.title,
    required this.json,
    required this.missing,
    this.headerPadding = EdgeInsets.zero,
    this.titleStyle,
  });

  final String title;
  final String? json;
  final String missing;
  final EdgeInsetsGeometry headerPadding;
  final TextStyle? titleStyle;

  @override
  State<ToolPayloadSection> createState() => _ToolPayloadSectionState();
}

class _ToolPayloadSectionState extends State<ToolPayloadSection> {
  late String text;
  late bool canCopy;
  @override
  void initState() {
    super.initState();
    _format();
  }

  @override
  void didUpdateWidget(ToolPayloadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.json != widget.json || oldWidget.missing != widget.missing) {
      _format();
    }
  }

  void _format() {
    final value = widget.json == null ? null : jsonDecode(widget.json!);
    final retained =
        !(value is Map && value['contentRetention'] == 'task_only');
    canCopy = widget.json != null && retained;
    text = !retained
        ? '此结果仅在执行时使用，未保留内容'
        : widget.json == null
        ? widget.missing
        : const JsonEncoder.withIndent('  ').convert(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: widget.headerPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style:
                        widget.titleStyle ??
                        TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                  ),
                ),
                if (canCopy)
                  Semantics(
                    button: true,
                    label: '复制${widget.title}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('已复制${widget.title}')),
                          );
                        } on Object catch (error) {
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('复制失败，请重试：${errorMessage(error)}'),
                            ),
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
            child: canCopy
                ? _JsonCode(text: text)
                : _PayloadScroll(
                    child: SelectableText(
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
          interactive: true,
          thumbVisibility: true,
          thickness: 4,
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

class _JsonCode extends StatefulWidget {
  const _JsonCode({required this.text});
  final String text;

  @override
  State<_JsonCode> createState() => _JsonCodeState();
}

class _JsonCodeState extends State<_JsonCode> {
  final _scroll = ScrollController();
  late List<String> _lines = widget.text.split('\n');
  List<double>? _lineHeights;
  double? _measuredWidth;
  TextScaler? _measuredScaler;
  TextDirection? _measuredDirection;

  List<double> _measureLines(
    BuildContext context,
    double width,
    TextStyle style,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    if (_lineHeights != null &&
        _measuredWidth == width &&
        _measuredScaler == scaler &&
        _measuredDirection == direction) {
      return _lineHeights!;
    }
    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    painter.text = TextSpan(text: '1', style: style);
    painter.layout();
    final minimum = painter.height;
    final heights = <String, double>{};
    _lineHeights = [
      for (final line in _lines)
        heights.putIfAbsent(line, () {
          painter.text = TextSpan(text: line, style: style);
          painter.layout(maxWidth: width);
          return painter.height < minimum ? minimum : painter.height;
        }),
    ];
    painter.dispose();
    _measuredWidth = width;
    _measuredScaler = scaler;
    _measuredDirection = direction;
    return _lineHeights!;
  }

  @override
  void didUpdateWidget(_JsonCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = widget.text.split('\n');
      _lineHeights = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    final lines = _lines;
    final style = TextStyle(
      fontSize: 13,
      height: 1.75,
      fontFamily: 'monospace',
      color: colors.onSurface,
    );
    Widget lineAt(int index) => IntrinsicHeight(
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
                    color: colors.onSurfaceVariant.withValues(alpha: .65),
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
                TextSpan(children: _highlight(lines[index], colors, dark)),
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
    if (lines.length <= 12) {
      return _PayloadScroll(
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < lines.length; i++) lineAt(i)],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 308,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: SelectionArea(
            child: Scrollbar(
              controller: _scroll,
              interactive: true,
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heights = _measureLines(
                    context,
                    constraints.maxWidth -
                        24 -
                        (14 + lines.length.toString().length * 8) -
                        13,
                    style,
                  );
                  return CustomScrollView(
                    controller: _scroll,
                    primary: false,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        sliver: SliverVariedExtentList(
                          itemExtentBuilder: (index, _) => heights[index],
                          delegate: _MeasuredPayloadDelegate(
                            (_, index) => lineAt(index),
                            childCount: lines.length,
                            totalExtent: heights.fold(
                              0.0,
                              (sum, height) => sum + height,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Varied extents still use a visible-child estimate unless the delegate
// supplies the full extent. Keep thumb dragging independent of visible rows.
class _MeasuredPayloadDelegate extends SliverChildBuilderDelegate {
  _MeasuredPayloadDelegate(
    super.builder, {
    required super.childCount,
    required this.totalExtent,
  });

  final double totalExtent;

  @override
  double estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => totalExtent;
}
