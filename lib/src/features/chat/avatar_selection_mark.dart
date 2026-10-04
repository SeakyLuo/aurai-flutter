import 'package:flutter/material.dart';
import 'settings_icon.dart';

class AvatarSelectionMark extends StatelessWidget {
  const AvatarSelectionMark({
    super.key,
    required this.selected,
    required this.child,
    this.inset = 5,
  });

  final bool selected;
  final Widget child;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(padding: EdgeInsets.all(inset), child: child),
        if (selected)
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Container(
                  width: 18,
                  height: 18,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onSurface,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: SettingsIcon(
                    type: SettingsIconType.check,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
