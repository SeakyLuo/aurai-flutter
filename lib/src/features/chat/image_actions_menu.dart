import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'attachment_action_icon.dart';

Future<String?> showImageActionsMenu(
  BuildContext context,
  Offset position, {
  bool canLocate = false,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭图片菜单',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 160),
  pageBuilder: (context, animation, _) {
    final media = MediaQuery.of(context);
    final width = math.min(200.0, media.size.width - 32);
    return Stack(
      children: [
        Positioned(
          left: position.dx.clamp(16, media.size.width - width - 16),
          top: position.dy.clamp(
            media.padding.top + 8,
            math.max(
              media.padding.top + 8,
              media.size.height -
                  media.padding.bottom -
                  (canLocate ? 188 : 132),
            ),
          ),
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: GlassSurface(
              radius: 24,
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in [
                        ('share', '转发', AttachmentActionIconType.forward),
                        ('save', '下载', AttachmentActionIconType.download),
                        if (canLocate)
                          ('locate', '定位消息', AttachmentActionIconType.locate),
                      ])
                        InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => Navigator.pop(context, action.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                AttachmentActionIcon(type: action.$3),
                                const SizedBox(width: 13),
                                Text(
                                  action.$2,
                                  style: const TextStyle(fontSize: 15),
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
      ],
    );
  },
);
