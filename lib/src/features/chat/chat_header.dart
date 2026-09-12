import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';
import 'conversation_more.dart';
import 'chat_controller.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({
    super.key,
    required this.onMenu,
    required this.controller,
    required this.beforeDelete,
  });
  final VoidCallback onMenu;
  final ChatController controller;
  final bool Function() beforeDelete;
  @override
  Size get preferredSize => const Size.fromHeight(76);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    forceMaterialTransparency: true,
    systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    flexibleSpace: Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: MediaQuery.paddingOf(context).top + 18,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            ],
            stops: [0, 0.65, 1],
          ),
        ),
      ),
    ),
    toolbarHeight: 76,
    titleSpacing: 18,
    title: Row(
      children: [
        GlassSurface(
          radius: 28,
          child: RoundAction(
            icon: Icons.menu_rounded,
            label: '会话菜单',
            onPressed: onMenu,
          ),
        ),
        const Spacer(),
        if (controller.messages.isNotEmpty)
          ConversationMore(controller: controller, beforeDelete: beforeDelete),
      ],
    ),
  );
}
