import 'chat_header_background.dart';
import '../../app/global_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'glass_surface.dart';

// Read the window inset: Scaffold's body padding already includes the app bar.
double settingsHeaderHeight(BuildContext context) =>
    View.of(context).padding.top / View.of(context).devicePixelRatio +
    SettingsAppBar.toolbarHeight;

EdgeInsets settingsPagePadding(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(top: settingsHeaderHeight(context) + padding.top);

class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({
    super.key,
    required this.child,
    this.avoidHeader = false,
  });

  final Widget child;
  // Fixed forms and search controls stay below the header. Scrollable pages
  // instead use settingsPagePadding inside their outermost scroll view.
  final bool avoidHeader;

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: avoidHeader
        ? Padding(
            padding: EdgeInsets.only(top: settingsHeaderHeight(context)),
            child: child,
          )
        : child,
  );
}

Color settingsFieldColor(BuildContext context) =>
    GlobalUI.controlBackground(Theme.of(context));

Color dialogControlColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? CupertinoColors.secondarySystemFill.resolveFrom(context)
    : settingsFieldColor(context);

class SettingsGlassAction extends StatelessWidget {
  static Color foregroundColor(BuildContext context, {required bool enabled}) {
    final color = Theme.of(context).colorScheme.onSurface;
    return enabled ? color : color.withValues(alpha: 0.3);
  }

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
  Widget build(BuildContext context) => SettingsGlassActionSurface(
    child: RoundAction(
      label: label,
      icon: icon,
      onPressed: onPressed,
      iconWidget:
          iconWidget ??
          Icon(
            icon,
            size: 25,
            color: foregroundColor(context, enabled: onPressed != null),
          ),
    ),
  );
}

class SettingsGlassActionSurface extends StatelessWidget {
  const SettingsGlassActionSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      GlassSurface(radius: 28, shadowOpacity: .55, child: child);
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
  });

  final String title;
  final bool root;
  final Widget? titleWidget;
  final Widget? leadingAction;
  final VoidCallback? onBack;
  final List<Widget> actions;

  static const double toolbarHeight = 76;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    forceMaterialTransparency: true,
    flexibleSpace: const ChatHeaderBackground(),
    centerTitle: true,
    toolbarHeight: toolbarHeight,
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
