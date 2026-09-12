import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/chat/chat_controller.dart';
import '../platform/aurai_platform.dart';
import 'aurai_app.dart';
import 'appearance_settings.dart';
import 'global_ui.dart';
import 'startup_brand.dart';

class AuraiStartup extends StatefulWidget {
  const AuraiStartup({super.key});

  @override
  State<AuraiStartup> createState() => _AuraiStartupState();
}

class _AuraiStartupState extends State<AuraiStartup> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  ChatController? _controller;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    _messenger.currentState?.clearSnackBars();
    final controller = ChatController(AuraiPlatform.instance);
    try {
      await AppearanceSettings.instance.load();
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Object {
      controller.dispose();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messenger.currentState!.showSnackBar(
          SnackBar(
            content: const Text('无法打开会话，请重试'),
            duration: const Duration(days: 365),
            dismissDirection: DismissDirection.none,
            action: SnackBarAction(label: '重试', onPressed: _open),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => _controller != null
      ? AuraiApp(key: const ValueKey('app'), controller: _controller!)
      : MaterialApp(
          key: const ValueKey('startup'),
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: GlobalUI.theme,
          scaffoldMessengerKey: _messenger,
          home: const StartupBrand(),
        );
}
