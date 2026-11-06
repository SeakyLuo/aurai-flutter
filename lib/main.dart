import 'package:flutter/material.dart';

import 'src/app/aurai_startup.dart';
import 'src/diagnostics/execution_log.dart';
import 'src/html_games/miniapp_task_app.dart';
import 'src/html_games/miniapp_task_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ExecutionLog.captureFlutterErrors();
  MiniappTaskHost.install();
  runApp(const AuraiStartup());
}

/// Android full-screen miniapps own a task; inline cards and split panes
/// continue using the application engine.
@pragma('vm:entry-point')
void miniappMain() {
  WidgetsFlutterBinding.ensureInitialized();
  ExecutionLog.captureFlutterErrors();
  runApp(const MiniappTaskApp());
}
