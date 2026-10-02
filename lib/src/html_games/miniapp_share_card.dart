import 'dart:io';
import 'package:flutter/material.dart';

import '../domain/miniapp_share.dart';
import '../features/chat/settings_appearance.dart';
import 'miniapp_icon.dart';
import 'miniapp_symbol.dart';

/// The same card is used in the conversation and the share confirmation.
class MiniappShareCard extends StatelessWidget {
  const MiniappShareCard({
    super.key,
    required this.share,
    this.onTap,
    this.onLongPress,
    this.fitAvailableHeight = false,
  });
  final MiniappShare share;
  final VoidCallback? onTap, onLongPress;
  final bool fitAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = SizedBox(
      width: 300,
      child: Material(
        color: dialogControlColor(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    MiniappIcon(
                      path: share.iconPath,
                      asset: share.iconAsset,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        share.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  share.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: AspectRatio(
                  aspectRatio: 5 / 4,
                  child: share.imagePath != null
                      ? Image.file(File(share.imagePath!), fit: BoxFit.cover)
                      : ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Center(
                            child: MiniappIcon(
                              path: share.iconPath,
                              asset: share.iconAsset,
                              size: 88,
                            ),
                          ),
                        ),
                ),
              ),
              Divider(height: 1, thickness: .5, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    MiniappSymbol(size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '小程序',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: fitAvailableHeight ? Alignment.center : Alignment.topLeft,
      child: card,
    );
  }
}
