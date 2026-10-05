import 'package:flutter/material.dart';
import 'settings_icon.dart';

class MemberSelectionMark extends StatelessWidget {
  const MemberSelectionMark({super.key, required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.onSurface : Colors.transparent,
        border: Border.all(
          color: selected ? colors.onSurface : colors.outline,
          width: 1.4,
        ),
      ),
      child: selected
          ? SettingsIcon(type: SettingsIconType.check, color: colors.surface)
          : null,
    );
  }
}
