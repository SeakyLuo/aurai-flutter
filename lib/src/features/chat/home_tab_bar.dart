import 'package:flutter/material.dart';
import 'conversation_icon.dart';
import 'glass_surface.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';

class HomeTabBar extends StatelessWidget {
  const HomeTabBar({
    super.key,
    required this.selected,
    required this.pages,
    required this.onSelected,
  });
  final int selected;
  final PageController pages;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(24, 4, 24, 8),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassSurface(
          radius: 30,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: pages,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: constraints.maxWidth / 3,
                          height: constraints.maxHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                      builder: (context, child) {
                        final page = pages.hasClients
                            ? (pages.page ?? pages.initialPage.toDouble())
                            : pages.initialPage.toDouble();
                        return Transform.translate(
                          offset: Offset(
                            page.clamp(0.0, 2.0) * constraints.maxWidth / 3,
                            0,
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    _tab(
                      context,
                      0,
                      '会话',
                      ConversationIcon(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : const Color(0xff222222),
                      ),
                    ),
                    _tab(
                      context,
                      1,
                      '通讯录',
                      const SettingsIcon(type: SettingsIconType.contacts),
                    ),
                    _tab(
                      context,
                      2,
                      '设置',
                      const SidebarActionIcon(
                        type: SidebarActionIconType.settings,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tab(BuildContext context, int index, String label, Widget icon) =>
      Expanded(
        child: Semantics(
          selected: selected == index,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => onSelected(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: Center(child: icon)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected == index
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
