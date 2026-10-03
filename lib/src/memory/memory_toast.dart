import '../app/glass_notice.dart';
import 'package:flutter/material.dart';

void memoryToast(
  BuildContext context,
  String text, {
  ToastKind kind = ToastKind.info,
}) => ScaffoldMessenger.of(
  context,
).showToast(SnackBar(content: Text(text)), kind: kind);
