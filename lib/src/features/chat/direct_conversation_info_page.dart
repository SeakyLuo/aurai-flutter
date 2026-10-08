import '../../domain/avatar_style.dart';
import 'profile_avatar.dart';
import 'profile_navigation.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../domain/error_message.dart';
import '../../storage/conversation_rows.dart';
import '../../storage/development_projects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_conversations_page.dart';

import 'ai_contact_page.dart';
import 'ai_contacts_page.dart';
import 'app_confirmation_dialog.dart';
import 'contact_remark_action.dart';
import 'chat_controller.dart';
import 'conversation_rename_dialog.dart';
import 'private_tasks_page.dart';
import 'group_apps_section.dart';
import 'group_favorites_page.dart';
import 'group_pinned_message_entry.dart';
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
  bool _isFriend = false;
  List<DevelopmentProject> _projects = const [];
  String get _detailsTitle =>
      _conversation.isPersonalChat ? '聊天详情' : '${_conversation.typeLabel}详情';

  Future<void> _openApp(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    await runUiAction(
      context,
      () => widget.controller.selectConversation(_conversation.id),
    );
    if (mounted) await _reload();
  }

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
        widget.controller.groupStore.loadAi(_conversation.defaultSenderId),
        widget.controller.projects.list(),
        widget.controller.groupStore.database.query(
          'contact_friendships',
          columns: ['friend_id'],
          where: "owner_id = 'user:local' AND friend_id = ?",
          whereArgs: [_conversation.defaultSenderId],
          limit: 1,
        ),
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
        _isFriend = (results[3] as List<Map<String, Object?>>).isNotEmpty;
        _failed = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text('$_detailsTitle加载失败：${errorMessage(error)}')),
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
        typeLabel: _conversation.typeLabel,
      ),
    ),
  );

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
    if (!mounted) return;
    await runUiAction(
      context,
      () => widget.controller.selectConversation(_conversation.id),
    );
    if (mounted) await _reload();
  }

  Future<void> _chooseHandler() async {
    final handler = await Navigator.push<AiProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => AiContactsPage(
          controller: widget.controller,
          selectForConversation: true,
          returnSelection: true,
        ),
      ),
    );
    if (!mounted ||
        handler == null ||
        handler.sender.id == _conversation.defaultSenderId)
      return;
    final stop = widget.controller.taskHandlerNeedsStop(_conversation.id);
    if (stop) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AppConfirmationDialog(
          title: '停止当前执行并更换处理人？',
          description: '停止后由${handler.sender.displayName}接手，已有记录会保留。',
          confirmLabel: '停止并更换',
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await runUiAction(
      context,
      () => _perform(() async {
        await widget.controller.setTaskHandler(
          _conversation.id,
          handler.sender.id,
          stopRunning: stop,
        );
        _conversation = await widget.controller.conversationDetails(
          _conversation.id,
        );
      }),
    );
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
      kind: ToastKind.success,
    );
  });

  DevelopmentProject get _assignedProject =>
      _projects.singleWhere((project) => project.id == _conversation.projectId);

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => DeleteConfirmationDialog(
        title: '删除${_conversation.typeLabel}？',
        description: '“${_conversation.title}”的消息、草稿和图片将一并删除，无法恢复。',
      ),
    );
    if (mounted && confirmed == true) {
      await _perform(widget.onDelete, leaveDeleted: true);
    }
  }

  Future<void> _copyTaskId() => runUiAction(context, () async {
    await Clipboard.setData(ClipboardData(text: _conversation.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showToast(
      const SnackBar(content: Text('已复制任务 ID')),
      kind: ToastKind.success,
    );
  }).then((_) {});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _detailsTitle,
        onBack: _busy ? null : () => Navigator.pop(context),
        actions: [
          if (_conversation.isPersonalChat && _isFriend)
            SettingsGlassAction(
              label: '设置备注名',
              icon: Icons.edit_outlined,
              iconWidget: const SettingsIcon(type: SettingsIconType.note),
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => editContactRemark(
                        context,
                        widget.controller,
                        _conversation.defaultSenderId,
                      ),
                    ),
            ),
        ],
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
                        if (_conversation.isPersonalChat) ...[
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
                                _profile!.sender.displayName,
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
                        ],
                        if (_conversation.isPersonalChat) ...[
                          _surface(
                            GroupAppsSection(
                              title: '应用',
                              onTaskList: () => _openApp(
                                AiConversationsPage(
                                  controller: widget.controller,
                                  profile: _profile!,
                                ),
                              ),
                              onTasks: () => _openApp(
                                PrivateTasksPage(
                                  controller: widget.controller,
                                  conversationId: _conversation.id,
                                  senderId: _conversation.defaultSenderId,
                                  originTaskId: widget.originTaskId,
                                ),
                              ),
                              onMarks: () => _openApp(
                                GroupFavoritesPage(
                                  controller: widget.controller,
                                  groupId: _conversation.id,
                                  groupTitle: _conversation.title,
                                  group: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_conversation.isPersonalChat) ...[
                          _surface(
                            GroupAppsSection(
                              title: '应用',
                              onTasks: () => _openApp(
                                PrivateTasksPage(
                                  controller: widget.controller,
                                  conversationId: _conversation.id,
                                  senderId: _conversation.defaultSenderId,
                                  originTaskId: widget.originTaskId,
                                ),
                              ),
                              onMarks: () => _openApp(
                                GroupFavoritesPage(
                                  controller: widget.controller,
                                  groupId: _conversation.id,
                                  groupTitle: _conversation.title,
                                  group: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _surface(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _detailRow(
                                  '任务名称',
                                  _conversation.title,
                                  _rename,
                                ),
                                _detailRow(
                                  '所属项目',
                                  _conversation.projectId == null
                                      ? '未加入项目'
                                      : _assignedProject.name,
                                  _chooseProject,
                                ),
                                _detailRow(
                                  '处理人',
                                  _profile!.sender.displayName,
                                  _chooseHandler,
                                  avatar: ProfileAvatar(
                                    style: AvatarStyle(
                                      icon: _profile!.sender.avatarIcon,
                                      color: _profile!.sender.avatarColor,
                                      path: _profile!.sender.avatarPath,
                                    ),
                                    name: _profile!.sender.displayName,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _surface(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _row(
                                '查找聊天记录',
                                () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupMessageSearchPage(
                                      controller: widget.controller,
                                      conversationId: _conversation.id,
                                      group: false,
                                      task: _conversation.isTask,
                                    ),
                                  ),
                                ),
                              ),
                              GroupPinnedMessageEntry(
                                controller: widget.controller,
                                groupId: _conversation.id,
                                embedded: true,
                              ),
                            ],
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
                              title: Text(
                                _conversation.isPersonalChat ? '置顶聊天' : '置顶任务',
                                style: TextStyle(fontSize: 15),
                              ),
                              value: _conversation.isPinned,
                              onChanged: _busy
                                  ? null
                                  : (_) => _perform(widget.onPin),
                            ),
                          ),
                        ],
                        if (_conversation.isTemporary) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: '保存此${_conversation.typeLabel}',
                            role: DialogActionRole.secondary,
                            onPressed: _busy
                                ? null
                                : () => _perform(widget.onSave),
                          ),
                        ],
                        if (_conversation.isTask &&
                            !_conversation.isTemporary) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: _conversation.isArchived
                                ? '取消归档'
                                : '归档${_conversation.typeLabel}',
                            role: DialogActionRole.secondary,
                            onPressed: _busy
                                ? null
                                : () => _perform(
                                    widget.onArchive,
                                    leaveArchived: !_conversation.isArchived,
                                  ),
                          ),
                        ],
                        if (!_conversation.isPersonalChat) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: '删除${_conversation.typeLabel}',
                            role: DialogActionRole.reject,
                            onPressed: _busy ? null : _confirmDelete,
                          ),
                        ],
                        if (_conversation.isTask) ...[
                          const SizedBox(height: 12),
                          DialogActionButton(
                            text: '复制任务 ID',
                            role: DialogActionRole.secondary,
                            onPressed: _busy ? null : _copyTaskId,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );

  Widget _detailRow(
    String label,
    String value,
    VoidCallback onTap, {
    Widget? avatar,
  }) => LayoutBuilder(
    builder: (context, constraints) => ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
      minTileHeight: settingsCardHeight,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .55),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[avatar, const SizedBox(width: 8)],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
      ),
      onTap: onTap,
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
