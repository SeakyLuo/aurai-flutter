import 'settings_icon.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'attachment_action_icon.dart';
import 'glass_surface.dart';

enum AttachmentSource { gallery, camera, file, favorite }

Future<AttachmentSource?> showImageSourceMenu(
  BuildContext context, {
  bool allowFavorites = true,
}) {
  final button = context.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(
            context,
            rootNavigator: true,
          ).overlay!.context.findRenderObject()!
          as RenderBox;
  final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
  final safe = MediaQuery.paddingOf(context);
  final width = math.min(212.0, overlay.size.width - safe.horizontal - 16);
  final left = origin.dx.clamp(
    safe.left + 8,
    overlay.size.width - safe.right - width - 8,
  );
  return showGeneralDialog<AttachmentSource>(
    context: context,
    requestFocus: false,
    barrierDismissible: true,
    barrierLabel: '关闭图片菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return Stack(
        children: [
          Positioned(
            left: left,
            bottom: overlay.size.height - origin.dy + 8,
            width: width,
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                alignment: Alignment.bottomLeft,
                scale: curve.drive(Tween(begin: 0.94, end: 1.0)),
                child: SlideTransition(
                  position: curve.drive(
                    Tween(begin: const Offset(0, 0.06), end: Offset.zero),
                  ),
                  child: GlassSurface(
                    radius: 24,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(0, origin.dy - safe.top - 16),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AttachmentSourceItem(
                                source: AttachmentSource.gallery,
                                label: '图片',
                                icon: AttachmentActionIconType.gallery,
                              ),
                              _AttachmentSourceItem(
                                source: AttachmentSource.camera,
                                label: '拍照',
                                icon: AttachmentActionIconType.camera,
                              ),
                              _AttachmentSourceItem(
                                source: AttachmentSource.file,
                                label: '文件',
                                icon: AttachmentActionIconType.file,
                              ),
                              if (allowFavorites)
                                _AttachmentSourceItem(
                                  source: AttachmentSource.favorite,
                                  label: '收藏',
                                  icon: AttachmentActionIconType.file,
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
          ),
        ],
      );
    },
    transitionBuilder: (_, _, _, child) => child,
  );
}

class _AttachmentSourceItem extends StatelessWidget {
  const _AttachmentSourceItem({
    required this.source,
    required this.label,
    required this.icon,
  });
  final AttachmentSource source;
  final String label;
  final AttachmentActionIconType icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.pop(context, source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            source == AttachmentSource.favorite
                ? const SettingsIcon(type: SettingsIconType.star)
                : AttachmentActionIcon(type: icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
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
}
