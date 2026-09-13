import 'package:flutter/material.dart';

import '../../domain/source_reference.dart';
import 'glass_surface.dart';
import 'source_icon.dart';

Future<void> showSourcesSheet(
  BuildContext context, {
  required List<SourceReference> sources,
  required ValueChanged<String?> onOpenLink,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  elevation: 0,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .16),
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: sources.length == 1 ? .38 : .55,
    minChildSize: .28,
    maxChildSize: .9,
    expand: false,
    builder: (context, scrollController) => GlassSurface(
      radius: 28,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: sources.length + 1,
            itemBuilder: (context, index) {
              final colors = Theme.of(context).colorScheme;
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 18),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        '来源',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final source = sources[index - 1];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onOpenLink(source.url);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          SourceIcon(source: source, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              source.domain,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        source.title,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      if (source.publicationLabel != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          source.publicationLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (index < sources.length)
                        Divider(
                          height: 1,
                          thickness: .5,
                          color: colors.onSurface.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? .12
                                : .09,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  ),
);
