import 'profile_navigation.dart';
import '../../app/glass_notice.dart';
import '../../domain/ai_profile.dart';
import '../../domain/error_message.dart';
import '../../storage/conversation_rows.dart';
import '../../storage/development_projects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'conversation_rename_dialog.dart';
import 'private_tasks_page.dart';
import 'conversation_project_page.dart';
import 'delete_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'group_message_search_page.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class DirectConversationInfoPage extends StatefulWidget {
  const DirectConversationInfoPage({
    super.key,
    required this.controller,
    required this.conversation,
    required this.onSave,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
    this.originTaskId,
  });

  final ChatController controller;
  final Conversation conversation;
  final Future<void> Function() onSave;
  final Future<void> Function() onPin;
  final Future<void> Function() onArchive;
  final Future<void> Function() onDelete;
  final String? originTaskId;

  @override
  State<DirectConversationInfoPage> createState() =>
      _DirectConversationInfoPageState();
}

class _DirectConversationInfoPageState
    extends State<DirectConversationInfoPage> {
  late Conversation _conversation = widget.conversation;
  AiProfile? _profile;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  List<DevelopmentProject> _projects = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool leaveArchived = false}) async {
    try {
      final results = await Future.wait<Object>([
        widget.controller.groupStore.database.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [widget.conversation.id],
          limit: 1,
        ),
        widget.controller.groupStore.loadAi(
          widget.conversation.defaultSenderId,
        ),
        widget.controller.projects.list(),
      ]);
      if (!mounted) return;
      final rows = results[0] as List<Map<String, Object?>>;
      if (rows.isEmpty || (leaveArchived && rows.single['archived'] == 1)) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _conversation = conversationFromRow(rows.single);
        _profile = results[1] as AiProfile;
        _projects = results[2] as List<DevelopmentProject>;
        _failed = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text('会话详情加载失败，请重试：${errorMessage(error)}')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    bool leaveArchived = false,
    bool leaveDeleted = false,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (leaveDeleted) {
        Navigator.pop(context, true);
      } else {
        await _reload(leaveArchived: leaveArchived);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() => _perform(
    () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => ConversationRenameDialog(
        controller: widget.controller,
        conversationId: _conversation.id,
        initialTitle: _conversation.title,
      ),
    ),
  );

  Future<void> _copyConversationId() async {
    await Clipboard.setData(ClipboardData(text: _conversation.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showToast(
      const SnackBar(content: Text('已复制会话 ID')),
      kind: ToastKind.success,
    );
  }

  Future<void> _openProfile() async {
    await openProfileRoute(
      context,
      MaterialPageRoute(
        builder: (_) => AiContactPage(
          controller: widget.controller,
          senderId: _conversation.defaultSenderId,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _chooseProject() => _perform(() async {
    final selection = await ConversationProjectSheet.show(
      context,
      controller: widget.controller,
      projects: _projects,
      selectedProjectId: _conversation.projectId,
    );
    if (selection == null) return;
    await widget.controller.setConversationProject(
      _conversation,
      selection.projectId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showToast(
      SnackBar(
        content: Text(
          conversationProjectChangedMessage(_projects, selection.projectId),
        ),
      ),
    );
  });

  DevelopmentProject get _assignedProject =>
      _projects.singleWhere((project) => project.id == _conversation.projectId);

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => DeleteConfirmationDialog(
        title: '删除会话？',
        description: '“${_conversation.title}”的消息、草稿和图片将一并删除，无法恢复。',
      ),
    );
    if (mounted && confirmed == true) {
      await _perform(widget.onDelete, leaveDeleted: true);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '会话详情',
        onBack: _busy ? null : () => Navigator.pop(context),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? Center(
                child: TextButton(onPressed: _reload, child: const Text('重试')),
              )
            : AbsorbPointer(
                absorbing: _busy,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        settingsHeaderHeight(context) + 8,
                        16,
                        32,
                      ),
                      children: [
                        _surface(
                          ListTile(
                            contentPadding:
                                const EdgeInsetsDirectional.fromSTEB(
                                  16,
                                  8,
                                  12,
                                  8,
                                ),
                            leading: MemberAvatar(
                              sender: _profile!.sender,
                              size: 48,
                            ),
                            title: Text(
                              _profile!.sender.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: _profile!.description.isEmpty
                                ? null
                                : Text(
                                    _profile!.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: const SettingsIcon(
                              type: SettingsIconType.chevron,
                            ),
                            onTap: _openProfile,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surface(
                          ListTile(
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 12,
                            ),
                            minTileHeight: settingsCardHeight,
                            title: const Text(
                              '会话名称',
                              style: TextStyle(fontSize: 15),
                            ),
                            trailing: SizedBox(
                              width: MediaQuery.sizeOf(context).width * .5,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _conversation.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const SettingsIcon(
                                    type: SettingsIconType.chevron,
                                  ),
                                ],
                              ),
                            ),
                            onTap: _rename,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surface(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                contentPadding:
                                    const EdgeInsetsDirectional.only(
                                      start: 16,
                                      end: 12,
                                    ),
                                minTileHeight: settingsCardHeight,
                                title: const Text(
                                  '所属项目',
                                  style: TextStyle(fontSize: 15),
                                ),
                                trailing: SizedBox(
                                  width: MediaQuery.sizeOf(context).width * .5,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _conversation.projectId == null
                                              ? '未加入项目'
                                              : _assignedProject.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const SettingsIcon(
                                        type: SettingsIconType.chevron,
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: _chooseProject,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surface(
                          _row(
                            '查找聊天记录',
                            () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupMessageSearchPage(
                                  controller: widget.controller,
                                  conversationId: _conversation.id,
                                  group: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _surface(
                          _row(
                            '任务清单',
                            () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrivateTasksPage(
                                  controller: widget.controller,
                                  conversationId: _conversation.id,
                                  senderId: _conversation.defaultSenderId,
                                  originTaskId: widget.originTaskId,
                                ),
                              ),
                            ),
                            icon: const SettingsIcon(
                              type: SettingsIconType.tasks,
                            ),
                          ),
                        ),
                        if (!_conversation.isArchived &&
                            !_conversation.isTemporary) ...[
                          const SizedBox(height: 12),
                          _surface(
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              title: const Text(
                                '设为置顶',
                                style: TextStyle(fontSize: 15),
                              ),
                              value: _conversation.isPinned,
                              onChanged: (_) => _perform(widget.onPin),
                            ),
                          ),
                        ],
                        if (_conversation.isTemporary) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: '保存此聊天',
                            role: DialogActionRole.secondary,
                            onPressed: _busy
                                ? null
                                : () => _perform(widget.onSave),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DialogActionButton(
                          text: '复制会话 ID',
                          role: DialogActionRole.secondary,
                          onPressed: _busy ? null : _copyConversationId,
                        ),
                        if (!_conversation.isTemporary) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: _conversation.isArchived ? '取消归档' : '归档会话',
                            role: DialogActionRole.secondary,
                            onPressed: _busy
                                ? null
                                : () => _perform(
                                    widget.onArchive,
                                    leaveArchived: !_conversation.isArchived,
                                  ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DialogActionButton(
                          text: '删除会话',
                          role: DialogActionRole.reject,
                          onPressed: _busy ? null : _confirmDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );

  Widget _surface(Widget child) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff262626)
        : Colors.white,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _row(String title, VoidCallback onTap, {Widget? icon}) => ListTile(
    contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
    minTileHeight: settingsCardHeight,
    leading: icon,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: const SettingsIcon(type: SettingsIconType.chevron),
    onTap: onTap,
  );
}
