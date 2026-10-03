import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'ai_contact_page.dart';
import 'group_activity_sheet.dart';
import 'group_info_page.dart';
import 'direct_conversation_info_page.dart';
import 'conversation_task_navigation.dart';
import 'file_tool_icon.dart';
import 'header_action_menu.dart';
import 'archive_confirmation_dialog.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'menu_press_highlight.dart';
import 'project_profile_page.dart';
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
    this.showProjectAction = false,
  });

  final ChatController controller;
  final bool Function()? beforeDelete;
  final Conversation? conversation;
  final Widget? child;
  final VoidCallback? onChanged;
  final String? originTaskId;
  final bool showProjectAction;

  @override
  State<ConversationMore> createState() => _ConversationMoreState();
}

class _ConversationMoreState extends State<ConversationMore> {
  bool _saving = false;
  Conversation get _conversation =>
      widget.conversation ?? widget.controller.activeConversation;

  void _notice(String message, {ToastKind kind = ToastKind.info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showToast(SnackBar(content: Text(message)), kind: kind);
  }

  Future<void> _saveChat() async {
    setState(() => _saving = true);
    try {
      await widget.controller.saveTemporaryConversation(_conversation.id);
      _notice('已保存为正式会话', kind: ToastKind.success);
    } on Object catch (error) {
      _notice('聊天保存失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pin() async {
    setState(() => _saving = true);
    try {
      await widget.controller.toggleConversationPin(_conversation.id);
    } on Object catch (error) {
      _notice('置顶保存失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
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
    void notice(
      String message, {
      SnackBarAction? action,
      ToastKind kind = ToastKind.info,
    }) {
      if (messenger.mounted) {
        messenger.showToast(
          SnackBar(
            content: Text(message),
            action: action,
            persist: false,
            duration: const Duration(seconds: 6),
          ),
          kind: kind,
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
          notice(
            '撤销归档失败，请在已归档会话中重试：${errorMessage(error)}',
            kind: ToastKind.error,
          );
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
      notice('归档保存失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
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
        kind: ToastKind.success,
      );
    } on Object {
      notice('会话已归档，请返回会话列表', action: undo, kind: ToastKind.success);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete({bool confirmed = false}) async {
    if (!_canDelete()) return;
    if (!confirmed) {
      final accepted = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => DeleteConfirmationDialog(
          title: '删除会话？',
          description: '“${_conversation.title}”的消息、草稿和图片将一并删除，无法恢复。',
        ),
      );
      if (!mounted || accepted != true || !_canDelete()) return;
    }
    setState(() => _saving = true);
    final deletedId = _conversation.id;
    try {
      await widget.controller.deleteConversation(deletedId);
      _notice('会话已删除', kind: ToastKind.success);
      if (mounted && widget.conversation == null) _closeDetails();
    } on FileSystemException catch (error) {
      _notice('会话已删除，部分图片文件清理失败：${errorMessage(error)}', kind: ToastKind.error);
    } on Object catch (error) {
      _notice('删除失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
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
    final hasProject =
        widget.showProjectAction && _conversation.projectId != null;
    final safe = MediaQuery.paddingOf(context);
    final menuWidth = 212.0;
    final menuHeight =
        (_conversation.isTemporary
            ? 202.0
            : _conversation.isArchived
            ? 202.0
            : 264.0) +
        (hasTask ? 54 : 0) +
        (hasProject ? 54 : 0);
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
                              GlassMenuItem(
                                icon: const ConversationMenuIcon(
                                  type: ConversationMenuIconType.profile,
                                ),
                                label: '查看朋友',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.profile,
                                ),
                              ),
                            if (isGroup)
                              GlassMenuItem(
                                icon: const ConversationMenuIcon(
                                  type: ConversationMenuIconType.members,
                                ),
                                label: '群成员',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.members,
                                ),
                              ),
                            if (_conversation.isTemporary)
                              GlassMenuItem(
                                icon: const ConversationMenuIcon(
                                  type: ConversationMenuIconType.unarchive,
                                ),
                                label: '保存此聊天',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.save,
                                ),
                              ),
                            if (hasTask)
                              GlassMenuItem(
                                icon: const ConversationMenuIcon(
                                  type: ConversationMenuIconType.task,
                                ),
                                label: '查看任务',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.task,
                                ),
                              ),
                            if (hasProject)
                              GlassMenuItem(
                                icon: const FileToolIcon(
                                  type: FileToolIconType.folder,
                                ),
                                label: '查看项目',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.project,
                                ),
                              ),
                            if (!_conversation.isArchived &&
                                !_conversation.isTemporary)
                              GlassMenuItem(
                                icon: ConversationMenuIcon(
                                  type: pinned
                                      ? ConversationMenuIconType.unpin
                                      : ConversationMenuIconType.pin,
                                ),
                                label: pinned ? '取消置顶' : '置顶',
                                onTap: () =>
                                    Navigator.pop(menuContext, _MoreAction.pin),
                              ),
                            GlassMenuItem(
                              icon: const ConversationMenuIcon(
                                type: ConversationMenuIconType.rename,
                              ),
                              label: '重命名',
                              onTap: () => Navigator.pop(
                                menuContext,
                                _MoreAction.rename,
                              ),
                            ),

                            if (!_conversation.isTemporary)
                              GlassMenuItem(
                                icon: ConversationMenuIcon(
                                  type: _conversation.isArchived
                                      ? ConversationMenuIconType.unarchive
                                      : ConversationMenuIconType.archive,
                                ),
                                label: _conversation.isArchived
                                    ? '取消归档'
                                    : '归档会话',
                                onTap: () => Navigator.pop(
                                  menuContext,
                                  _MoreAction.archive,
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
      case _MoreAction.project:
        final project = await widget.controller.projects.read(
          _conversation.projectId!,
        );
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectProfilePage(
              controller: widget.controller,
              project: project,
            ),
          ),
        );
      case _MoreAction.pin:
        await _pin();
      case _MoreAction.members:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => GroupActivityPage(
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
      case null:
        break;
    }
    if (action != null) {
      widget.onChanged?.call();
    }
  }

  Future<void> _openDetails() async {
    final leftConversation = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _conversation.kind == ConversationKind.group
            ? GroupInfoPage(
                controller: widget.controller,
                conversation: _conversation,
                originTaskId: widget.originTaskId,
                onPin: _pin,
                onArchive: _archive,
              )
            : DirectConversationInfoPage(
                controller: widget.controller,
                conversation: _conversation,
                originTaskId: widget.originTaskId,
                onSave: _saveChat,
                onPin: _pin,
                onArchive: _archive,
                onDelete: () => _delete(confirmed: true),
              ),
      ),
    );
    if (!mounted) return;
    widget.onChanged?.call();
    if (leftConversation == true && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child != null
      ? MenuPressHighlight(
          onLongPressStart: _saving
              ? null
              : (details) => _openMenu(details.globalPosition),
          borderRadius: BorderRadius.circular(16),
          child: widget.child!,
        )
      : GlassSurface(
          radius: 28,
          shadowOpacity: .8,
          child: RoundAction(
            icon: Icons.more_vert_rounded,
            label: '会话详情',
            onPressed: _saving ? null : _openDetails,
            onLongPress: _saving ? null : _openMenu,
          ),
        );
}

enum _MoreAction { profile, task, project, members, pin, rename, archive, save }
