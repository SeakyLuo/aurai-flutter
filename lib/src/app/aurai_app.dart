import 'package:flutter/material.dart';

import '../features/chat/chat_controller.dart';
import '../features/chat/chat_page.dart';

class AuraiApp extends StatelessWidget {
  const AuraiApp({super.key, required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aurai',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff1685f8),
        primary: const Color(0xff1685f8),
        surface: Colors.white,
        onSurface: const Color(0xff171717),
        onSurfaceVariant: const Color(0xff737580),
        outlineVariant: const Color(0xffe9e9f0),
      ),
      scaffoldBackgroundColor: Colors.white,
      dividerTheme: const DividerThemeData(
        color: Color(0xffededf2),
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xff171717),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff7f7fa),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: ChatPage(controller: controller),
  );
}
