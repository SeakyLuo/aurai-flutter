import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../domain/avatar_style.dart';
import 'glass_surface.dart';
import 'profile_avatar.dart';
import 'question_icon.dart';

class ViewableProfileAvatar extends StatelessWidget {
  const ViewableProfileAvatar({
    super.key,
    required this.style,
    required this.name,
    this.size = 88,
  });

  final AvatarStyle style;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看$name的头像大图',
    child: GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => _ProfileAvatarPreview(style: style, name: name),
        ),
      ),
      child: ProfileAvatar(style: style, name: name, size: size),
    ),
  );
}

class _ProfileAvatarPreview extends StatelessWidget {
  const _ProfileAvatarPreview({required this.style, required this.name});

  final AvatarStyle style;
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) - 48;
        return Stack(
          fit: StackFit.expand,
          children: [
            PhotoView.customChild(
              childSize: Size.square(size),
              minScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 4,
              onTapUp: (_, _, _) => Navigator.pop(context),
              child: ProfileAvatar(style: style, name: name, size: size),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: GlassSurface(
                  dark: true,
                  tintOpacity: .6,
                  radius: 24,
                  shadowOpacity: .8,
                  child: RoundAction(
                    label: '关闭预览',
                    icon: Icons.close,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
