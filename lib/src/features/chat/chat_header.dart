import 'chat_header_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/global_ui.dart';
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
  static const double toolbarHeight = GlobalUI.appBarHeight;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);
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
    flexibleSpace: const ChatHeaderBackground(),
    toolbarHeight: toolbarHeight,
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
                  shadowOpacity: .55,
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
                shadowOpacity: .55,
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
              ConversationMore(
                controller: controller,
                beforeDelete: beforeDelete,
                originTaskId: originTaskId,
              ),
            ],
          ),
  );
}
