import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'conversation_rename_dialog.dart';

class ConversationMore extends StatefulWidget {
  const ConversationMore({
    super.key,
    required this.controller,
    this.beforeDelete,
    this.conversation,
    this.child,
  });

  final ChatController controller;
  final bool Function()? beforeDelete;
  final Conversation? conversation;
  final Widget? child;

  @override
  State<ConversationMore> createState() => _ConversationMoreState();
}

class _ConversationMoreState extends State<ConversationMore> {
  bool _saving = false;
  Conversation get _conversation =>
      widget.conversation ?? widget.controller.activeConversation;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pin() async {
    setState(() => _saving = true);
    final wasPinned = _conversation.isPinned;
    try {
      await widget.controller.toggleConversationPin(_conversation.id);
      _notice(wasPinned ? '已取消置顶' : '会话已置顶');
    } on Object {
      _notice('置顶保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_canDelete()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话？'),
        content: Text('“${_conversation.title}”的消息、草稿和图片将一并删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !_canDelete()) return;
    setState(() => _saving = true);
    final deletedId = _conversation.id;
    try {
      await widget.controller.deleteConversation(deletedId);
      _notice('会话已删除');
    } on Object {
      _notice(
        widget.controller.conversations.any((item) => item.id == deletedId)
            ? '删除失败，请重试'
            : '会话已删除，部分图片文件清理失败',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canDelete() {
    if (_conversation.id != widget.controller.activeConversation.id)
      return true;
    if (widget.beforeDelete != null) return widget.beforeDelete!();
    if (widget.controller.isBusy ||
        widget.controller.addingImages ||
        widget.controller.changingConversation) {
      _notice('请等待当前操作完成，再删除会话');
      return false;
    }
    return true;
  }

  Future<void> _openMenu([Offset? position]) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final pinned = _conversation.isPinned;
    final targetId = _conversation.id;
    final safe = MediaQuery.paddingOf(context);
    final menuWidth = 212.0;
    final menuHeight = 202.0;
    final anchor =
        position ??
        Offset(
          origin.dx + button.size.width - menuWidth,
          origin.dy + button.size.height + 10,
        );
    final left = anchor.dx.clamp(
      safe.left + 8,
      overlay.size.width - safe.right - menuWidth - 8,
    );
    final top = anchor.dy.clamp(
      safe.top + 8,
      overlay.size.height - safe.bottom - menuHeight - 8,
    );
    final action = await showGeneralDialog<_MoreAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭更多菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (menuContext, animation, secondaryAnimation) {
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              width: 212,
              child: FadeTransition(
                opacity: curve,
                child: ScaleTransition(
                  alignment: Alignment.topRight,
                  scale: curve.drive(Tween(begin: 0.94, end: 1.0)),
                  child: GlassSurface(
                    radius: 24,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _GlassMenuItem(
                              icon: pinned
                                  ? ConversationMenuIconType.unpin
                                  : ConversationMenuIconType.pin,
                              label: pinned ? '取消置顶' : '置顶',
                              onTap: () =>
                                  Navigator.pop(menuContext, _MoreAction.pin),
                            ),
                            _GlassMenuItem(
                              icon: ConversationMenuIconType.rename,
                              label: '重命名',
                              onTap: () => Navigator.pop(
                                menuContext,
                                _MoreAction.rename,
                              ),
                            ),
                            _GlassMenuItem(
                              icon: ConversationMenuIconType.delete,
                              label: '删除会话',
                              destructive: true,
                              onTap: () => Navigator.pop(
                                menuContext,
                                _MoreAction.delete,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    if (!mounted) return;
    switch (action) {
      case _MoreAction.pin:
        await _pin();
      case _MoreAction.rename:
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ConversationRenameDialog(
            controller: widget.controller,
            conversationId: targetId,
            initialTitle: _conversation.title,
          ),
        );
      case _MoreAction.delete:
        await _delete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child != null
      ? GestureDetector(
          onLongPressStart: _saving
              ? null
              : (details) => _openMenu(details.globalPosition),
          child: widget.child,
        )
      : GlassSurface(
          radius: 28,
          child: RoundAction(
            icon: Icons.more_horiz_rounded,
            label: '更多',
            onPressed: _saving ? null : _openMenu,
          ),
        );
}

enum _MoreAction { pin, rename, delete }

class _GlassMenuItem extends StatelessWidget {
  const _GlassMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final ConversationMenuIconType icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        hoverColor: const Color(0x0c695383),
        highlightColor: const Color(0x14695383),
        splashColor: const Color(0x14695383),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          child: Row(
            children: [
              ConversationMenuIcon(type: icon, color: color),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
