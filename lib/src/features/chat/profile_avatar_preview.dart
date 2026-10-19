import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../domain/avatar_style.dart';
import 'glass_surface.dart';
import 'profile_avatar.dart';
import 'question_icon.dart';

ImageProvider? _originalAvatarImage(AvatarStyle style) => style.path != null
    ? FileImage(File(style.path!))
    : style.icon == 'app_logo'
    ? const AssetImage('assets/branding/app_logo.png')
    : null;

Widget _avatarFlight(
  AvatarStyle style,
  String name,
  Animation<double> animation,
) {
  final original = _originalAvatarImage(style);
  return AnimatedBuilder(
    animation: animation,
    builder: (_, child) => LayoutBuilder(
      builder: (_, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(
          constraints.biggest.shortestSide * .5 * (1 - animation.value),
        ),
        child: child,
      ),
    ),
    child: original != null
        ? Image(image: original, fit: BoxFit.cover)
        : FittedBox(
            child: ProfileAvatar(
              style: style,
              name: name,
              size: 512,
              borderRadius: BorderRadius.zero,
            ),
          ),
  );
}

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
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => _ProfileAvatarPreview(
            style: widget.style,
            name: widget.name,
            heroTag: _heroTag,
          ),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeInOutCubic)),
            child: child,
          ),
        ),
      ),
      child: Hero(
        tag: _heroTag,
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        flightShuttleBuilder: (_, animation, _, _, _) =>
            _avatarFlight(widget.style, widget.name, animation),
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

  PhotoViewHeroAttributes get _heroAttributes => PhotoViewHeroAttributes(
    tag: heroTag,
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: (_, animation, _, _, _) =>
        _avatarFlight(style, name, animation),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) - 48;
        final original = _originalAvatarImage(style);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (original != null)
              PhotoView(
                imageProvider: original,
                heroAttributes: _heroAttributes,
                minScale: PhotoViewComputedScale.contained,
                initialScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                onTapUp: (_, _, _) => Navigator.pop(context),
              )
            else
              PhotoView.customChild(
                heroAttributes: _heroAttributes,
                childSize: Size.square(size),
                minScale: PhotoViewComputedScale.contained,
                initialScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                onTapUp: (_, _, _) => Navigator.pop(context),
                child: ProfileAvatar(
                  style: style,
                  name: name,
                  size: size,
                  borderRadius: BorderRadius.zero,
                ),
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
