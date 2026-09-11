import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'compose_icon.dart';
import 'glass_surface.dart';

enum ConversationAction { create, select, settings, model, capabilities, clear }

typedef ConversationSelection = ({ConversationAction action, String? id});

Future<ConversationSelection?> showConversationsSheet(
  BuildContext context,
  ChatController controller,
) => showGeneralDialog<ConversationSelection>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭会话列表',
  barrierColor: Colors.black.withValues(alpha: 0.24),
  transitionDuration: const Duration(milliseconds: 220),
  transitionBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  ),
  pageBuilder: (context, animation, secondary) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: math.min(380, MediaQuery.sizeOf(context).width * 0.84),
      height: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: _ConversationsDrawer(controller: controller),
      ),
    ),
  ),
);

class _ConversationsDrawer extends StatefulWidget {
  const _ConversationsDrawer({required this.controller});
  final ChatController controller;
  @override
  State<_ConversationsDrawer> createState() => _ConversationsDrawerState();
}

class _ConversationsDrawerState extends State<_ConversationsDrawer> {
  final _search = TextEditingController();
  bool _searching = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(ConversationAction action, [String? id]) =>
      Navigator.pop(context, (action: action, id: id));

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final query = _search.text.trim().toLowerCase();
          final conversations = controller.conversations
              .where(
                (item) =>
                    item.title.toLowerCase().contains(query) ||
                    item.draft.toLowerCase().contains(query),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '会话',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    RoundAction(
                      icon: Icons.search_rounded,
                      label: '搜索会话',
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _search.clear();
                      }),
                    ),
                    RoundAction(
                      icon: Icons.close_rounded,
                      label: '关闭',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索会话',
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空搜索',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Text(
                  '最近',
                  style: TextStyle(fontSize: 13, color: Color(0xff96999f)),
                ),
              ),
              Expanded(
                child: conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '没有找到会话',
                              style: TextStyle(color: Color(0xff92969d)),
                            ),
                            TextButton(
                              onPressed: () => setState(_search.clear),
                              child: const Text('清空搜索'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          final selected =
                              conversation.id ==
                              controller.activeConversation.id;
                          return Semantics(
                            selected: selected,
                            button: true,
                            child: Material(
                              color: selected
                                  ? const Color(0xfff1f2f3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _choose(
                                  ConversationAction.select,
                                  conversation.id,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 17,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conversation.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xff242424),
                                        ),
                                      ),
                                      if (conversation.messages.isEmpty &&
                                          conversation.draft.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          conversation.draft,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff96999f),
                                          ),
                                        ),
                                      ],
                                      if (conversation.pendingGoal != null) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          selected && controller.isBusy
                                              ? '任务进行中'
                                              : '有待继续的任务',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff96999f),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _choose(ConversationAction.create),
                        icon: const ComposeIcon(color: Colors.white),
                        label: const Text('新建会话'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    RoundAction(
                      icon: Icons.settings_outlined,
                      label: '设置',
                      onPressed: () => _choose(ConversationAction.settings),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<ConversationSelection?> showConversationSettings(
  BuildContext context,
  ChatController controller,
) => showModalBottomSheet<ConversationSelection>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              '设置',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
          ),
          for (final item in const [
            (ConversationAction.model, Icons.tune_rounded, '模型设置'),
            (
              ConversationAction.capabilities,
              Icons.phone_android_outlined,
              '设备能力',
            ),
            (ConversationAction.clear, Icons.delete_outline_rounded, '清空当前会话'),
          ])
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () =>
                    Navigator.pop(context, (action: item.$1, id: null)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(item.$2, size: 22, color: const Color(0xff626873)),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$3, style: const TextStyle(fontSize: 16)),
                            if (item.$1 == ConversationAction.model) ...[
                              const SizedBox(height: 5),
                              Text(
                                controller.needsConfiguration
                                    ? '连接模型'
                                    : modelDisplayName(controller.config.model),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff96999f),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xffa3a7ad),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
