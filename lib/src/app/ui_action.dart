import 'package:flutter/material.dart';
import '../domain/error_message.dart';
import 'glass_notice.dart';

/// Presentation boundary: business operations propagate errors to this layer.
Future<bool> runUiAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
    return false;
  }
}
