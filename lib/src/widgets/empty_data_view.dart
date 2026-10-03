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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/illustrations/empty_box.png',
              width: 144,
              height: 144,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
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
                icon: actionIcon == null
                    ? null
                    : SizedBox.square(
                        dimension: 18,
                        child: FittedBox(child: actionIcon),
                      ),
                onPressed: onAction,
                height: 42,
                fontSize: 14,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
