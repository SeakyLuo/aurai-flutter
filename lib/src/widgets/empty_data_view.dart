import 'package:flutter/material.dart';

import '../utils/widget_utils.dart';

/// Shared illustration and typography for empty collections and search results.
class EmptyDataView extends StatelessWidget {
  const EmptyDataView({
    super.key,
    required this.title,
    this.description,
    this.actionText,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? description;
  final String? actionText;
  final Widget? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/illustrations/empty_box.png',
              width: 176,
              height: 176,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionText != null) ...[
              const SizedBox(height: 24),
              WidgetUtils.primaryButton(
                text: actionText!,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
