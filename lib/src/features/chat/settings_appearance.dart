import 'package:flutter/material.dart';

import 'glass_surface.dart';

Color settingsFieldColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff262626)
    : const Color(0xfff3f3f3);

class SettingsGlassAction extends StatelessWidget {
  const SettingsGlassAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconWidget,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 28,
    child: RoundAction(
      label: label,
      icon: icon,
      onPressed: onPressed,
      iconWidget:
          iconWidget ??
          Icon(
            icon,
            size: 25,
            color: onPressed == null
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.onSurface,
          ),
    ),
  );
}

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: true,
    toolbarHeight: 76,
    leadingWidth: 64,
    title: Text(title),
    leading: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Center(
        child: SettingsGlassAction(
          label: '返回',
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
        ),
      ),
    ),
    actions: [
      for (final action in actions)
        Padding(padding: const EdgeInsets.only(right: 16), child: action),
    ],
  );
}
