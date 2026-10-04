import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import '../../domain/avatar_portraits.dart';
import 'avatar_background.dart';
import 'avatar_symbol.dart';

ImageProvider avatarPortraitImage(
  String icon,
  double size,
  double pixelRatio,
) => ResizeImage.resizeIfNeeded(
  (size * (avatarPortraitScales[icon] ?? 1) * pixelRatio).ceil(),
  null,
  AssetImage(avatarPortraits[icon]!.asset),
);

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.style,
    required this.name,
    this.size = 88,
    this.borderRadius,
  });
  final AvatarStyle style;
  final String name;
  final double size;
  final BorderRadius? borderRadius;
  @override
  Widget build(BuildContext context) {
    if (style.icon == 'app_logo' && style.path == null) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        child: Image.asset(
          'assets/branding/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final background = AvatarBackground.decode(style.color);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: background.gradient),
        alignment: Alignment.center,
        child: style.path != null
            ? Image.file(
                File(style.path!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(background.foreground),
              )
            : avatarPortraits.containsKey(style.icon)
            ? Align(
                alignment:
                    style.icon == 'portrait:snail' ||
                        style.icon == 'portrait:saturn' ||
                        style.icon == 'portrait:sunglasses_bee' ||
                        style.icon == 'portrait:dumpling' ||
                        style.icon == 'portrait:double_scoop_ice_cream'
                    ? Alignment.center
                    : Alignment.bottomCenter,
                child: Transform.scale(
                  scale: (avatarPortraitScales[style.icon] ?? 1) > 1
                      ? avatarPortraitScales[style.icon]!
                      : 1,
                  child: Image(
                    image: avatarPortraitImage(
                      style.icon,
                      size,
                      MediaQuery.devicePixelRatioOf(context),
                    ),
                    width: size * (avatarPortraitScales[style.icon] ?? 1),
                    height: size * (avatarPortraitScales[style.icon] ?? 1),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : style.icon == 'initial'
            ? _initial(background.foreground)
            : SizedBox.square(
                dimension: size * (style.icon == 'app_logo_white' ? .62 : .46),
                child: FittedBox(
                  child: AvatarSymbol(
                    symbol: style.icon,
                    color: background.foreground,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _initial(Color color) => Text(
    name.trim().isEmpty ? '你' : name.trim().characters.first.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: size * .42,
      fontWeight: FontWeight.w400,
    ),
  );
}
