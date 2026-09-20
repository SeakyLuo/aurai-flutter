import '../app/glass_notice.dart';
import 'package:flutter/material.dart';

void memoryToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));
