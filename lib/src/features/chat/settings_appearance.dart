import 'chat_header_background.dart';
import '../../app/global_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'glass_surface.dart';

Color settingsFieldColor(BuildContext context) =>
    GlobalUI.controlBackground(Theme.of(context));

Color dialogControlColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? CupertinoColors.secondarySystemFill.resolveFrom(context)
    : settingsFieldColor(context);

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
    this.titleWidget,
    this.leadingAction,
    this.root = false,
    this.gradientBackground = false,
  });

  final String title;
  final bool root;
  final bool gradientBackground;
  final Widget? titleWidget;
  final Widget? leadingAction;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: gradientBackground ? Colors.transparent : null,
    surfaceTintColor: gradientBackground ? Colors.transparent : null,
    shadowColor: gradientBackground ? Colors.transparent : null,
    elevation: gradientBackground ? 0 : null,
    scrolledUnderElevation: gradientBackground ? 0 : null,
    forceMaterialTransparency: gradientBackground,
    flexibleSpace: gradientBackground ? const ChatHeaderBackground() : null,
    centerTitle: true,
    toolbarHeight: 76,
    leadingWidth: 64,
    title: titleWidget ?? Text(title),
    automaticallyImplyLeading: false,
    leading: leadingAction != null
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(child: leadingAction),
          )
        : root
        ? null
        : Padding(
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
