import 'package:flutter/material.dart';

import 'dialog_action_button.dart';
import 'glass_surface.dart';

Future<bool> confirmDataAction(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _DataDialog(
        title: title,
        children: [
          Text(description, style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 24),
          DialogActionButton(
            text: action,
            role: destructive
                ? DialogActionRole.destructive
                : DialogActionRole.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          DialogActionButton(
            text: '取消',
            role: DialogActionRole.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ) ??
    false;

class _DataDialog extends StatelessWidget {
  const _DataDialog({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: GlassSurface(
        radius: 28,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}
