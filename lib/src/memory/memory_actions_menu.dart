import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/conversation_menu_icon.dart';

enum MemoryAction { edit, delete }

Future<MemoryAction?> showMemoryActionsMenu(
  BuildContext context,
  Offset position,
) => showGeneralDialog<MemoryAction>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭记忆菜单',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, animation, secondaryAnimation) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final width = math.min(
      212.0,
      media.size.width - media.padding.horizontal - 16,
    );
    final bottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        8;
    final height = math.min(
      16 + 104 * math.max(1, media.textScaler.scale(16) / 16),
      bottom - media.padding.top - 8,
    );
    final left = (position.dx - width / 2).clamp(
      media.padding.left + 8,
      media.size.width - media.padding.right - width - 8,
    );
    final top = (position.dy + 12).clamp(
      media.padding.top + 8,
      bottom - height,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: GlassSurface(
                radius: 24,
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bottom - top),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final action in MemoryAction.values)
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pop(context, action),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    ConversationMenuIcon(
                                      type: action == MemoryAction.edit
                                          ? ConversationMenuIconType.rename
                                          : ConversationMenuIconType.delete,
                                      color: action == MemoryAction.delete
                                          ? colors.error
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      action == MemoryAction.edit ? '编辑' : '删除',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: action == MemoryAction.delete
                                            ? colors.error
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  },
);
