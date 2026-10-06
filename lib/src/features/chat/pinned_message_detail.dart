import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';

class PinnedMessageDetail extends StatelessWidget {
  const PinnedMessageDetail({
    super.key,
    required this.onBack,
    required this.onLocate,
    this.onMore,
    this.title = '置顶详情',
    required this.child,
  });
  final VoidCallback onBack, onLocate;
  final ValueChanged<BuildContext>? onMore;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: title,
      onBack: onBack,
      actions: [
        SettingsGlassActionSurface(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundAction(
                label: '定位',
                icon: Icons.my_location,
                iconWidget: AttachmentActionIcon(
                  type: AttachmentActionIconType.locate,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: onLocate,
              ),
              if (onMore != null) ...[
                const SizedBox(height: 20, child: VerticalDivider(width: 1)),
                Builder(
                  builder: (anchor) => RoundAction(
                    label: '更多',
                    icon: Icons.more_vert_rounded,
                    onPressed: () => onMore!(anchor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    body: SettingsPageBody(
      child: ListView(
        padding: settingsPagePadding(
          context,
          const EdgeInsets.only(top: 12, bottom: 24),
        ),
        children: [child],
      ),
    ),
  );
}
