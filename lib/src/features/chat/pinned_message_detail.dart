import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'question_sheet.dart';

class PinnedMessageDetail extends StatelessWidget {
  const PinnedMessageDetail({
    super.key,
    required this.onBack,
    required this.onLocate,
    this.onMore,
    this.title = '置顶详情',
    this.sheet = false,
    required this.child,
  });
  final VoidCallback onBack, onLocate;
  final ValueChanged<BuildContext>? onMore;
  final String title;
  final bool sheet;
  final Widget child;
  @override
  Widget build(BuildContext context) => sheet
      ? QuestionSheetLayout(
          title: title,
          heading: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SettingsGlassActionSurface(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundAction(
                        label: '定位',
                        icon: Icons.my_location,
                        iconWidget: const AttachmentActionIcon(
                          type: AttachmentActionIconType.locate,
                        ),
                        onPressed: onLocate,
                      ),
                      if (onMore != null) ...[
                        const SizedBox(
                          height: 20,
                          child: VerticalDivider(width: 1),
                        ),
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
          ),
          child: child,
        )
      : Scaffold(
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
                      const SizedBox(
                        height: 20,
                        child: VerticalDivider(width: 1),
                      ),
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
