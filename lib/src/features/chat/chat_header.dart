import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';
import 'conversation_more.dart';
import 'chat_controller.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({
    super.key,
    required this.controller,
    required this.beforeDelete,
    this.editing = false,
    this.onCancelEdit,
    required this.onBack,
    this.originTaskId,
  });
  final String? originTaskId;
  final VoidCallback onBack;
  final ChatController controller;
  final bool Function() beforeDelete;
  final bool editing;
  final VoidCallback? onCancelEdit;
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
    flexibleSpace: controller.activeConversation.kind == ConversationKind.group
        ? LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                for (var index = 0; index < 16; index++)
                  Positioned(
                    top: constraints.maxHeight * index / 16,
                    height: constraints.maxHeight / 16,
                    left: 0,
                    right: 0,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 6 * (1 - index / 15),
                          sigmaY: 6 * (1 - index / 15),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .65),
                        Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: MediaQuery.paddingOf(context).top + (editing ? 76 : 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.95),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: [0, 0.65, 1],
                ),
              ),
            ),
          ),
    toolbarHeight: 76,
    titleSpacing: 18,
    title: editing
        ? Stack(
            alignment: Alignment.center,
            children: [
              const Center(child: Text('编辑消息')),
              Align(
                alignment: Alignment.centerLeft,
                child: GlassSurface(
                  radius: 28,
                  child: RoundAction(
                    icon: Icons.close_rounded,
                    label: '取消编辑',
                    onPressed: onCancelEdit,
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              GlassSurface(
                radius: 28,
                child: RoundAction(
                  icon: Icons.arrow_back_rounded,
                  label: '返回',
                  onPressed: onBack,
                ),
              ),
              Expanded(
                child:
                    controller.activeConversation.kind == ConversationKind.group
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          controller.activeConversation.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (controller.messages.isNotEmpty ||
                  controller.activeConversation.kind == ConversationKind.group)
                ConversationMore(
                  controller: controller,
                  beforeDelete: beforeDelete,
                  originTaskId: originTaskId,
                ),
            ],
          ),
  );
}
