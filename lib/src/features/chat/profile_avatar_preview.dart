import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../domain/avatar_style.dart';
import 'glass_surface.dart';
import 'profile_avatar.dart';
import 'question_icon.dart';

class ViewableProfileAvatar extends StatefulWidget {
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
  State<ViewableProfileAvatar> createState() => _ViewableProfileAvatarState();
}

class _ViewableProfileAvatarState extends State<ViewableProfileAvatar> {
  final Object _heroTag = Object();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看${widget.name}的头像大图',
    child: GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => _ProfileAvatarPreview(
            style: widget.style,
            name: widget.name,
            heroTag: _heroTag,
          ),
        ),
      ),
      child: Hero(
        tag: _heroTag,
        child: ProfileAvatar(
          style: widget.style,
          name: widget.name,
          size: widget.size,
        ),
      ),
    ),
  );
}

class _ProfileAvatarPreview extends StatelessWidget {
  const _ProfileAvatarPreview({
    required this.style,
    required this.name,
    required this.heroTag,
  });

  final AvatarStyle style;
  final String name;
  final Object heroTag;

  ImageProvider? get _originalImage => style.path != null
      ? FileImage(File(style.path!))
      : style.icon == 'app_logo'
      ? const AssetImage('assets/branding/app_logo.png')
      : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) - 48;
        final original = _originalImage;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (original != null)
              PhotoView(
                imageProvider: original,
                heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                minScale: PhotoViewComputedScale.contained,
                initialScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                onTapUp: (_, _, _) => Navigator.pop(context),
              )
            else
              PhotoView.customChild(
                heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
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
