import 'package:flutter/material.dart';

import 'src/app/aurai_app.dart';
import 'src/features/chat/chat_controller.dart';
import 'src/platform/aurai_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ChatController(AuraiPlatform.instance);
  await controller.initialize();
  runApp(AuraiApp(controller: controller));
}
