import 'package:flutter/material.dart';

import '../../scheduling/task_action_menu.dart';

class HtmlMessageMoreButton extends StatelessWidget {
  static const top = 0.0;
  static const right = 6.0;

  const HtmlMessageMoreButton({
    super.key,
    required this.onPressed,
    this.label = '更多',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    icon: SizedBox.square(
      dimension: 18,
      child: TaskActionIcon(
        'more',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(32),
      minimumSize: const Size.square(32),
      padding: const EdgeInsets.all(7),
    ),
  );
}
