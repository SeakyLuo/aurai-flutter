import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// Shared project dialog surface. Custom content owns its scrolling behavior.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.child,
    this.maxWidth = 320,
    this.regular = false,
  });

  final Widget child;
  final double maxWidth;
  final bool regular;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(radius: 28, regular: regular, child: child),
    ),
  );
}

/// Standard title, description and actions for project prompts.
class AppPromptDialog extends StatelessWidget {
  const AppPromptDialog({
    super.key,
    required this.title,
    this.description,
    required this.actions,
    this.regular = false,
  });

  final String title;
  final String? description;
  final Widget actions;
  final bool regular;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppDialog(
      regular: regular,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            actions,
          ],
        ),
      ),
    );
  }
}
