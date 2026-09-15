import '../../domain/error_message.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'ai_contact_page.dart';
import 'group_members_page.dart';
import 'group_info_page.dart';
import 'sidebar_action_icon.dart';
import 'conversation_task_navigation.dart';
import 'settings_icon.dart';
import 'archive_confirmation_dialog.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'conversation_rename_dialog.dart';
import 'delete_confirmation_dialog.dart';

class ConversationMore extends StatefulWidget {
  const ConversationMore({
    super.key,
    required this.controller,
    this.beforeDelete,
    this.conversation,
    this.child,
    this.onChanged,
    this.originTaskId,
  });

  final ChatController controller;
  final bool Function()? beforeDelete;
  final Conversation? conversation;
  final Widget? child;
  final VoidCallback? onChanged;
  final String? originTaskId;

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

  Future<void> _saveChat() async {
    setState(() => _saving = true);
    try {
      await widget.controller.saveTemporaryConversation(_conversation.id);
      _notice('已保存为正式会话');
    } on Object catch (error) {
      _notice('聊天保存失败，请重试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pin() async {
    setState(() => _saving = true);
    try {
      await widget.controller.toggleConversationPin(_conversation.id);
    } on Object catch (error) {
      _notice('置顶保存失败，请重试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final target = _conversation;
    final controller = widget.controller;
    final wasArchived = target.isArchived;
    if (!wasArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => ArchiveConfirmationDialog(
          isCurrent: target.id == controller.activeConversation.id,
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    void notice(String message, {SnackBarAction? action}) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: action,
            persist: false,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }

    final undo = SnackBarAction(
      label: '撤销',
      onPressed: () async {
        try {
          await controller.setConversationArchived(target.id, archived: false);
          notice('已撤销归档');
        } on Object catch (error) {
          notice('撤销归档失败，请在已归档会话中重试：${errorMessage(error)}');
        }
      },
    );

    setState(() => _saving = true);
    try {
      await controller.setConversationArchived(
        target.id,
        archived: !wasArchived,
      );
    } on Object catch (error) {
      notice('归档保存失败，请重试：${errorMessage(error)}');
      if (mounted) setState(() => _saving = false);
      return;
    }
    try {
      if (!wasArchived && widget.conversation == null && mounted) {
        await controller.createConversation();
        if (mounted) _closeDetails();
      }
      notice(
        wasArchived ? '已取消归档' : '会话已归档',
        action: wasArchived ? null : undo,
      );
    } on Object {
      notice('会话已归档，请返回会话列表', action: undo);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_canDelete()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => DeleteConfirmationDialog(
        title: '删除会话？',
        description: '“${_conversation.title}”的消息、草稿和图片将一并删除，无法恢复。',
      ),
    );
    if (!mounted || confirmed != true || !_canDelete()) return;
    setState(() => _saving = true);
    final deletedId = _conversation.id;
    try {
      await widget.controller.deleteConversation(deletedId);
      _notice('会话已删除');
      if (mounted && widget.conversation == null) _closeDetails();
    } on FileSystemException catch (error) {
      _notice('会话已删除，部分图片文件清理失败：${errorMessage(error)}');
    } on Object catch (error) {
      _notice('删除失败，请重试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _closeDetails() {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context)!;
    navigator.popUntil((candidate) => candidate == route);
    navigator.pop();
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
    if (widget.child == null && _conversation.kind == ConversationKind.group) {
      final leftGroup = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GroupInfoPage(
            controller: widget.controller,
            conversation: _conversation,
            originTaskId: widget.originTaskId,
            onPin: _pin,
            onArchive: _archive,
            onDelete: _delete,
          ),
        ),
      );
      if (!mounted) return;
      widget.onChanged?.call();
      if (leftGroup == true && Navigator.canPop(context))
        Navigator.pop(context);
      return;
    }
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final pinned = _conversation.isPinned;
    final isGroup = _conversation.kind == ConversationKind.group;
    final targetId = _conversation.id;
    final senderId = _conversation.defaultSenderId;
    final hasTask = conversationTasks(
      widget.controller,
      targetId,
      originTaskId: widget.originTaskId,
    ).isNotEmpty;
    final safe = MediaQuery.paddingOf(context);
    final menuWidth = 212.0;
    final menuHeight =
        (_conversation.isTemporary
            ? 202.0
            : _conversation.isArchived
            ? 202.0
            : 264.0) +
        (hasTask ? 54 : 0) +
        54;
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
                            if (!isGroup)
                              _GlassMenuItem(
                                iconWidget: SettingsIcon(
                                  type: SettingsIconType.personalInfo,
                                  color: Theme.of(
                                    menuContext,
                                  ).colorScheme.onSurface,
                                ),
                                label: '查看资料',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.profile,
                                ),
                              ),
                            if (isGroup)
                              _GlassMenuItem(
                                iconWidget: SidebarActionIcon(
                                  type: SidebarActionIconType.group,
                                  color: Theme.of(
                                    menuContext,
                                  ).colorScheme.onSurface,
                                ),
                                label: '群成员',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.members,
                                ),
                              ),
                            if (_conversation.isTemporary)
                              _GlassMenuItem(
                                icon: ConversationMenuIconType.unarchive,
                                label: '保存此聊天',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.save,
                                ),
                              ),
                            if (hasTask)
                              _GlassMenuItem(
                                iconWidget: SettingsIcon(
                                  type: SettingsIconType.tasks,
                                  color: Theme.of(
                                    menuContext,
                                  ).colorScheme.onSurface,
                                ),
                                label: '查看任务',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.task,
                                ),
                              ),
                            if (!_conversation.isArchived &&
                                !_conversation.isTemporary)
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
                            if (!_conversation.isTemporary)
                              _GlassMenuItem(
                                icon: _conversation.isArchived
                                    ? ConversationMenuIconType.unarchive
                                    : ConversationMenuIconType.archive,
                                label: _conversation.isArchived ? '取消归档' : '归档',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.archive,
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
      case _MoreAction.profile:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AiContactPage(
              controller: widget.controller,
              senderId: senderId,
            ),
          ),
        );
      case _MoreAction.task:
        await openConversationTask(
          context,
          widget.controller,
          targetId,
          originTaskId: widget.originTaskId,
        );
      case _MoreAction.pin:
        await _pin();
      case _MoreAction.members:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => GroupMembersPage(
              controller: widget.controller,
              conversationId: targetId,
            ),
          ),
        );
      case _MoreAction.rename:
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: .24),
          builder: (_) => ConversationRenameDialog(
            controller: widget.controller,
            conversationId: targetId,
            initialTitle: _conversation.title,
          ),
        );
      case _MoreAction.save:
        await _saveChat();
      case _MoreAction.archive:
        await _archive();
      case _MoreAction.delete:
        await _delete();
      case null:
        break;
    }
    if (action != null) widget.onChanged?.call();
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

enum _MoreAction { profile, task, members, pin, rename, archive, delete, save }

class _GlassMenuItem extends StatelessWidget {
  const _GlassMenuItem({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final ConversationMenuIconType? icon;
  final Widget? iconWidget;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              iconWidget ?? ConversationMenuIcon(type: icon!, color: color),
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
