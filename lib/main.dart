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

/// Reserved Android entry point. Existing miniapp launchers intentionally keep
/// using in-app routes and split panes; no user-facing entry opens a task yet.
@pragma('vm:entry-point')
void miniappMain() {
  WidgetsFlutterBinding.ensureInitialized();
  ExecutionLog.captureFlutterErrors();
  runApp(const MiniappTaskApp());
}
