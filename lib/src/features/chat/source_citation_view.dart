import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../domain/source_reference.dart';
import 'source_citation_syntax.dart';
import 'source_icon.dart';
import 'sources_sheet.dart';

class SourceCitationBuilder extends MarkdownElementBuilder {
  SourceCitationBuilder({required this.onOpenLink});
  final ValueChanged<String?> onOpenLink;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final sources = citationGroup(element);
    final colors = Theme.of(context).colorScheme;
    final chip = SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: '查看 ${sources.length} 个来源',
          child: Material(
            color: colors.onSurface.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showSourcesSheet(
                context,
                sources: sources,
                onOpenLink: onOpenLink,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .48,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SourceIcon(source: sources.first, size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        sources.first.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (sources.length > 1)
                      Text(
                        ' +${sources.length - 1}',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // A WidgetSpan lets the capsule follow the last word on the same line.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: chip),
        ],
      ),
    );
  }
}

class MessageSourcesButton extends StatelessWidget {
  const MessageSourcesButton({
    super.key,
    required this.sources,
    required this.onOpenLink,
  });
  final List<SourceReference> sources;
  final ValueChanged<String?> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final sites = <String, SourceReference>{};
    for (final source in sources) {
      sites.putIfAbsent(source.domain, () => source);
    }
    return TextButton(
      onPressed: () =>
          showSourcesSheet(context, sources: sources, onOpenLink: onOpenLink),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in sites.values.take(3))
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: SourceIcon(source: source, size: 16),
            ),
          const SizedBox(width: 5),
          const Text('来源', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
