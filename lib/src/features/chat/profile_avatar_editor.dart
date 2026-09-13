import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import 'profile_avatar.dart';
import 'glass_surface.dart';
import 'conversation_menu_icon.dart';
import 'attachment_action_icon.dart';

enum AvatarSource { gallery, camera, custom }

class ProfileAvatarEditor extends StatelessWidget {
  const ProfileAvatarEditor({
    super.key,
    required this.style,
    required this.name,
    required this.onSelected,
  });
  final AvatarStyle style;
  final String name;
  final ValueChanged<AvatarSource>? onSelected;

  Future<void> _menu(BuildContext context) async {
    final anchor = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay!.context.findRenderObject()!
            as RenderBox;
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final width = 212.0;
    final left = (origin.dx + anchor.size.width / 2 - width / 2).clamp(
      8.0,
      overlay.size.width - width - 8,
    );
    final source = await showGeneralDialog<AvatarSource>(
      context: context,
      requestFocus: false,
      barrierDismissible: true,
      barrierLabel: '关闭头像菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, _) {
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return Stack(
          children: [
            Positioned(
              left: left,
              top: origin.dy + anchor.size.height + 8,
              width: width,
              child: FadeTransition(
                opacity: curve,
                child: ScaleTransition(
                  alignment: Alignment.topCenter,
                  scale: curve.drive(Tween(begin: .94, end: 1.0)),
                  child: GlassSurface(
                    radius: 24,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in [
                              (
                                AvatarSource.gallery,
                                '上传图片',
                                AttachmentActionIconType.gallery,
                              ),
                              (
                                AvatarSource.camera,
                                '拍照',
                                AttachmentActionIconType.camera,
                              ),
                              (
                                AvatarSource.custom,
                                '自定义头像',
                                AttachmentActionIconType.file,
                              ),
                            ])
                              ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                leading: item.$1 == AvatarSource.custom
                                    ? ConversationMenuIcon(
                                        type: ConversationMenuIconType.rename,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      )
                                    : AttachmentActionIcon(type: item.$3),
                                title: Text(
                                  item.$2,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                onTap: () => Navigator.pop(context, item.$1),
                              ),
                          ],
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
    if (source != null) onSelected!(source);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      child: Semantics(
        button: true,
        label: '编辑头像',
        child: Builder(
          builder: (anchorContext) => GestureDetector(
            onTap: onSelected == null ? null : () => _menu(anchorContext),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  ProfileAvatar(style: style, name: name),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      child: GlassSurface(
                        radius: 16,
                        child: ColoredBox(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0x38404040)
                              : const Color(0x20707070),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: ConversationMenuIcon(
                              type: ConversationMenuIconType.rename,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
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
  );
}
