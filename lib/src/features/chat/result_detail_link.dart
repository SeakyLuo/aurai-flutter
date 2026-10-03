import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import 'settings_icon.dart';

class ResultDetailLink extends StatelessWidget {
  const ResultDetailLink({
    super.key,
    required this.icon,
    required this.name,
    required this.open,
  });
  final Widget icon;
  final String name;
  final Future<void> Function() open;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .5)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 44,
          minLeadingWidth: 18,
          horizontalTitleGap: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: SizedBox.square(
            dimension: 18,
            child: FittedBox(child: icon),
          ),
          title: Text(
            name,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: () => runUiAction(context, open),
        ),
      ],
    );
  }
}
