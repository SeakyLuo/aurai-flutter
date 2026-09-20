import '../features/chat/home_navigation.dart';
import '../html_games/html_route_observer.dart';
import '../features/chat/image_action_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'global_ui.dart';
import 'appearance_settings.dart';
import 'package:flutter/services.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/home_page.dart';
import '../features/chat/conversation_notifications.dart';

class AuraiApp extends StatelessWidget {
  const AuraiApp({super.key, required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppearanceSettings.instance,
    builder: (context, child) => MaterialApp(
      title: 'Aurai',
      navigatorObservers: [homeRouteObserver, htmlRouteObserver],
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: GlobalUI.theme,
      darkTheme: GlobalUI.darkTheme,
      themeMode: AppearanceSettings.instance.mode,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                systemNavigationBarColor: Theme.of(context).colorScheme.surface,
                systemNavigationBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
              ),
          child: ImageActionScope(controller: controller, child: child!),
        );
      },
      routes: {'/': (_) => child!},
      onGenerateInitialRoutes: (_) => initialHomeRoutes(controller, child!),
    ),
    child: ConversationNotifications(
      controller: controller,
      child: HomePage(key: HomePage.navigationKey, controller: controller),
    ),
  );
}
