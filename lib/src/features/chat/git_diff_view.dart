import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'settings_appearance.dart';

enum _GitDiffLineKind { context, added, removed }

class _GitDiffLineData {
  const _GitDiffLineData({
    required this.kind,
    required this.text,
    this.oldLine,
    this.newLine,
  });

  final _GitDiffLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;
}

class GitDiffView extends StatelessWidget {
  const GitDiffView({
    super.key,
    required this.diff,
    required this.truncated,
    required this.wrapLines,
  });

  final String diff;
  final bool truncated;
  final bool wrapLines;

  List<_GitDiffLineData> _lines() {
    final result = <_GitDiffLineData>[];
    final header = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
    int? oldLine;
    int? newLine;
    for (final raw in diff.split('\n')) {
      final match = header.firstMatch(raw);
      if (match != null) {
        oldLine = int.parse(match.group(1)!);
        newLine = int.parse(match.group(2)!);
        continue;
      }
      if (oldLine == null || newLine == null || raw.startsWith(r'\')) {
        continue;
      }
      if (raw.startsWith('+')) {
        result.add(
          _GitDiffLineData(
            kind: _GitDiffLineKind.added,
            text: raw.substring(1),
            newLine: newLine,
          ),
        );
        newLine++;
      } else if (raw.startsWith('-')) {
        result.add(
          _GitDiffLineData(
            kind: _GitDiffLineKind.removed,
            text: raw.substring(1),
            oldLine: oldLine,
          ),
        );
        oldLine++;
      } else {
        result.add(
          _GitDiffLineData(
            kind: _GitDiffLineKind.context,
            text: raw.startsWith(' ') ? raw.substring(1) : raw,
            oldLine: oldLine,
            newLine: newLine,
          ),
        );
        oldLine++;
        newLine++;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    final longest = lines.fold<int>(
      0,
      (value, line) => math.max(value, line.text.length),
    );
    final highestLine = lines.fold<int>(
      0,
      (value, line) =>
          math.max(value, math.max(line.oldLine ?? 0, line.newLine ?? 0)),
    );
    final gutterWidth = math
        .max(28.0, highestLine.toString().length * 7 + 12)
        .toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math
            .max(
              constraints.maxWidth,
              math.min(8000, longest * 7.8 + gutterWidth + 38),
            )
            .toDouble();
        final itemCount = math.max(1, lines.length) + (truncated ? 1 : 0);
        Widget content(double contentWidth) => SizedBox(
          width: contentWidth,
          height: constraints.maxHeight,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              0,
              settingsHeaderHeight(context) + 12,
              0,
              24,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (lines.isEmpty && index == 0) {
                return const _GitDiffNotice(text: '文件内容发生变动，无法显示文本差异。');
              }
              if (index == lines.length) {
                return const _GitDiffNotice(text: '改动较多，仅显示部分内容。');
              }
              return _GitDiffLine(line: lines[index], gutterWidth: gutterWidth);
            },
          ),
        );
        if (wrapLines) return content(constraints.maxWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content(width),
        );
      },
    );
  }
}

class _GitDiffLine extends StatelessWidget {
  const _GitDiffLine({required this.line, required this.gutterWidth});

  final _GitDiffLineData line;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = switch (line.kind) {
      _GitDiffLineKind.added => const Color(
        0xff00ad8b,
      ).withValues(alpha: dark ? .15 : .10),
      _GitDiffLineKind.removed => colors.error.withValues(
        alpha: dark ? .15 : .09,
      ),
      _GitDiffLineKind.context => Colors.transparent,
    };
    final foreground = switch (line.kind) {
      _GitDiffLineKind.added =>
        dark ? const Color(0xff70dfc7) : const Color(0xff087f68),
      _GitDiffLineKind.removed => colors.error,
      _GitDiffLineKind.context => colors.onSurface,
    };
    final marker = switch (line.kind) {
      _GitDiffLineKind.added => '+',
      _GitDiffLineKind.removed => '−',
      _GitDiffLineKind.context => '',
    };
    final lineNumber = switch (line.kind) {
      _GitDiffLineKind.removed => line.oldLine,
      _ => line.newLine,
    };
    return ColoredBox(
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineNumber(value: lineNumber, width: gutterWidth),
          Container(
            width: 1,
            height: 23,
            color: colors.outlineVariant.withValues(alpha: .7),
          ),
          SizedBox(
            width: 20,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                marker,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                  color: foreground,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 16, 2),
              child: SelectableText(
                line.text.isEmpty ? ' ' : line.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                  color: foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineNumber extends StatelessWidget {
  const _LineNumber({required this.value, required this.width});

  final int? value;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      child: Text(
        value?.toString() ?? '',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.55,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _GitDiffNotice extends StatelessWidget {
  const _GitDiffNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
