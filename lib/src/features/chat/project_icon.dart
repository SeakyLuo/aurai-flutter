import 'package:flutter/material.dart';

import '../../skills/skill_icon.dart';
import 'avatar_background.dart';

class ProjectIcon extends StatelessWidget {
  const ProjectIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (icon.startsWith('emoji:')) {
      return SizedBox.square(
        dimension: size,
        child: FittedBox(
          child: Text(
            icon.substring(6),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(fontSize: 24, height: 1),
          ),
        ),
      );
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        color == 'default'
            ? Theme.of(context).colorScheme.onSurface
            : AvatarBackground.decode(color).start,
        BlendMode.srcIn,
      ),
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(child: SkillIcon(icon)),
      ),
    );
  }
}
