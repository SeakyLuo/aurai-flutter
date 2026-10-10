import 'package:flutter/material.dart';

import '../../app/global_ui.dart';
import 'settings_icon.dart';

class TaskEntryCard extends StatefulWidget {
  const TaskEntryCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.failed,
    required this.onTap,
  });

  final String title, description, status;
  final bool failed;
  final Future<void> Function()? onTap;

  @override
  State<TaskEntryCard> createState() => _TaskEntryCardState();
}

class _TaskEntryCardState extends State<TaskEntryCard> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      await widget.onTap!();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TaskEntryCard(:title, :description, :status, :failed, :onTap) =
        widget;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: onTap != null,
      label: '$title，$description，$status',
      child: Material(
        color: GlobalUI.messageBackground(theme),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap != null && !_opening ? _open : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: FittedBox(
                    child: SettingsIcon(
                      type: SettingsIconType.job,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: (failed ? colors.error : colors.onSurfaceVariant)
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: failed ? colors.error : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const SizedBox.square(
                    dimension: 18,
                    child: FittedBox(
                      child: SettingsIcon(type: SettingsIconType.chevron),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
