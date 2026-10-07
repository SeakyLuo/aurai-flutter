import '../../app/ui_action.dart';
import 'group_avatar_page.dart';
import '../../storage/development_projects.dart';
import 'conversation_project_page.dart';
import 'group_personal_details.dart';
import '../../storage/group_member_details.dart';
import '../../storage/group_chat_store.dart';
import 'group_pinned_message_entry.dart';
import 'group_favorites_page.dart';
import 'group_apps_section.dart';
import 'group_tasks_page.dart';
import 'tools_page.dart';
import '../../skills/skills_page.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:math' as math;
import 'dialog_action_button.dart';
import 'group_invite_page.dart';
import 'group_management_page.dart';
import 'group_remove_members_page.dart';
import 'package:flutter/material.dart';

import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/conversation_rows.dart';
import 'member_profile_avatar.dart';
import 'chat_controller.dart';
import 'conversation_rename_dialog.dart';
import 'group_activity_sheet.dart';
import 'group_announcement_page.dart';
import 'markdown_preview_text.dart';
import '../../storage/group_announcement_store.dart';
import 'group_message_search_page.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'delete_confirmation_dialog.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({
    super.key,
    required this.controller,
    required this.conversation,
    required this.onPin,
    this.originTaskId,
  });

  final ChatController controller;
  final Conversation conversation;
  final Future<void> Function() onPin;
  final String? originTaskId;

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late Conversation _conversation = widget.conversation;
  List<ConversationMember> _members = [];
  GroupAnnouncement? _announcement;
  List<DevelopmentProject> _projects = [];
  late GroupManagementSettings _managementSettings;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  GroupMemberRole get _localRole => _members
      .firstWhere((member) => member.sender.id == MessageSender.localUser.id)
      .role;
  bool get _canManage => _localRole.canManage;
  bool get _canInvite =>
      _canManage || !_managementSettings.joinApprovalRequired;
  bool get _canRename => _canManage || !_managementSettings.managersOnlyRename;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool leaveArchived = false}) async {
    try {
      final results = await Future.wait<Object>([
        widget.controller.projects.list(),
        widget.controller.groupStore.database.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [widget.conversation.id],
        ),
        widget.controller.groupStore.members(widget.conversation.id),
        GroupAnnouncementStore(widget.controller.groupStore)
            .read(widget.conversation.id, MessageSender.localUser.id)
            .then((value) => <GroupAnnouncement>[if (value != null) value]),
        widget.controller.groupStore.managementSettings(
          widget.conversation.id,
          MessageSender.localUser.id,
        ),
      ]);
      if (!mounted) return;
      final rows = results[1] as List<Map<String, Object?>>;
      if (rows.isEmpty || (leaveArchived && rows.single['archived'] == 1)) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _projects = results[0] as List<DevelopmentProject>;
        _conversation = conversationFromRow(rows.single);
        _members = results[2] as List<ConversationMember>;
        _announcement = (results[3] as List<GroupAnnouncement>).firstOrNull;
        _managementSettings = results[4] as GroupManagementSettings;
        _failed = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('群聊信息加载失败，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    bool leaveArchived = false,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _reload(leaveArchived: leaveArchived);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await _reload();
  }

  Future<void> _openApp(Widget page) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _openSkills() async {
    await runUiAction(context, () async {
      final store = await widget.controller.aiSkills(
        MessageSender.localUser.id,
      );
      if (!mounted) return;
      await _openApp(
        SkillsPage(
          store: store,
          controller: widget.controller,
          library: true,
          groupId: _conversation.id,
          projectId: _conversation.projectId,
        ),
      );
    });
  }

  Future<void> _rename() => _perform(
    () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => ConversationRenameDialog(
        typeLabel: '群聊',
        controller: widget.controller,
        conversationId: _conversation.id,
        initialTitle: _conversation.title,
      ),
    ),
  );

  Future<void> _chooseProject() => _perform(() async {
    final selection = await ConversationProjectSheet.show(
      context,
      controller: widget.controller,
      projects: _projects,
      selectedProjectId: _conversation.projectId,
    );
    if (!mounted || selection == null) return;
    final saved = await runUiAction(
      context,
      () => widget.controller.setConversationProject(
        _conversation,
        selection.projectId,
      ),
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showToast(
      SnackBar(
        content: Text(
          conversationProjectChangedMessage(_projects, selection.projectId),
        ),
      ),
      kind: ToastKind.success,
    );
  });

  Widget _projectRow() => ListTile(
    contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
    minTileHeight: settingsCardHeight,
    title: const Text('所属项目', style: TextStyle(fontSize: 15)),
    trailing: SizedBox(
      width: MediaQuery.sizeOf(context).width * .5,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _conversation.projectId == null
                  ? '未加入项目'
                  : _projects
                        .singleWhere(
                          (project) => project.id == _conversation.projectId,
                        )
                        .name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_canManage) ...[
            const SizedBox(width: 8),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ],
      ),
    ),
    onTap: _canManage ? _chooseProject : null,
  );

  Future<void> _openManagement() async {
    final dissolved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupManagementPage(
          controller: widget.controller,
          groupId: _conversation.id,
          groupTitle: _conversation.title,
        ),
      ),
    );
    if (!mounted) return;
    if (dissolved == true) {
      Navigator.pop(context, true);
      return;
    }
    await _reload();
  }

  Future<void> _leave() async {
    if (_localRole == GroupMemberRole.owner) {
      ScaffoldMessenger.of(context).showToast(
        const SnackBar(content: Text('请先转让群主，或在群管理中解散群聊')),
        kind: ToastKind.warning,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '退出群聊？',
        description: '退出后将不再接收群消息，已有聊天记录仍会保留给其他成员。',
        confirmLabel: '退出',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.leaveGroup(_conversation.id);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('退出失败，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '群聊详情',
          onBack: _busy ? null : () => Navigator.pop(context),
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? Center(
                  child: TextButton(
                    onPressed: _reload,
                    child: const Text('重试'),
                  ),
                )
              : AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      settingsHeaderHeight(context) + 8,
                      16,
                      32,
                    ),
                    children: [
                      _surface(
                        Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsetsDirectional.only(
                                start: 16,
                                end: 12,
                              ),
                              minTileHeight: settingsCardHeight,
                              title: const Text(
                                '群成员',
                                style: TextStyle(fontSize: 15),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_members.length} 人',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const SettingsIcon(
                                    type: SettingsIconType.chevron,
                                  ),
                                ],
                              ),
                              onTap: () => _open(
                                GroupActivityPage(
                                  controller: widget.controller,
                                  conversationId: _conversation.id,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth < 320
                                      ? 4
                                      : 5;
                                  final slots =
                                      columns * 3 -
                                      (_canInvite ? 1 : 0) -
                                      (_canManage ? 1 : 0);
                                  final visible = math.min(
                                    _members.length,
                                    slots,
                                  );
                                  return GridView(
                                    padding: EdgeInsets.zero,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisExtent:
                                              62 +
                                              MediaQuery.textScalerOf(
                                                context,
                                              ).scale(17),
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 8,
                                        ),
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      for (
                                        var index = 0;
                                        index < visible;
                                        index++
                                      )
                                        _member(
                                          _members[index].sender,
                                          remaining:
                                              index == visible - 1 &&
                                                  _members.length > visible
                                              ? _members.length - visible + 1
                                              : 0,
                                        ),
                                      if (_canInvite)
                                        _memberAction(
                                          '邀请',
                                          SettingsIcon(
                                            type: SettingsIconType.add,
                                            color: colors.onSurfaceVariant,
                                          ),
                                          () => _open(
                                            GroupInvitePage(
                                              controller: widget.controller,
                                              conversationId: _conversation.id,
                                              members: _members,
                                            ),
                                          ),
                                        ),
                                      if (_canManage)
                                        _memberAction(
                                          '移除',
                                          const SettingsIcon(
                                            type: SettingsIconType.remove,
                                          ),
                                          () => _open(
                                            GroupRemoveMembersPage(
                                              controller: widget.controller,
                                              conversationId: _conversation.id,
                                              members: _members,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _surface(
                        GroupAppsSection(
                          onTasks: () => _openApp(
                            GroupTasksPage(
                              controller: widget.controller,
                              conversationId: _conversation.id,
                              originTaskId: widget.originTaskId,
                            ),
                          ),
                          onMarks: () => _openApp(
                            GroupFavoritesPage(
                              controller: widget.controller,
                              groupId: _conversation.id,
                              groupTitle: _conversation.title,
                            ),
                          ),
                          onTools: () => _openApp(
                            ToolsPage(
                              controller: widget.controller,
                              groupId: _conversation.id,
                              projectId: _conversation.projectId,
                            ),
                          ),
                          onSkills: _openSkills,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GroupPersonalDetails(
                        store: GroupMemberDetailsStore(
                          widget.controller.groupStore.database,
                        ),
                        groupId: _conversation.id,
                        joinedAt: _members
                            .firstWhere(
                              (m) => m.sender.id == MessageSender.localUser.id,
                            )
                            .joinedAt,
                        defaultName: MessageSender.localUser.name,
                        onChanged: _reload,
                        builder: (remark, identity) => Column(
                          children: [
                            _section([
                              GroupAvatarEntry(
                                controller: widget.controller,
                                conversation: _conversation,
                                canEdit: _canManage,
                              ),
                              ListTile(
                                contentPadding:
                                    const EdgeInsetsDirectional.only(
                                      start: 16,
                                      end: 12,
                                    ),
                                minTileHeight: settingsCardHeight,
                                title: const Text(
                                  '群名称',
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
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      if (_canRename) ...[
                                        const SizedBox(width: 8),
                                        const SettingsIcon(
                                          type: SettingsIconType.chevron,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                onTap: _canRename ? _rename : null,
                              ),
                              ListTile(
                                contentPadding:
                                    const EdgeInsetsDirectional.only(
                                      start: 16,
                                      end: 12,
                                    ),
                                minTileHeight: settingsCardHeight,
                                title: const Text(
                                  '群公告',
                                  style: TextStyle(fontSize: 15),
                                ),
                                subtitle: _announcement == null
                                    ? null
                                    : Text(
                                        markdownPreviewText(
                                          _announcement!.content,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_announcement == null) ...[
                                      Text(
                                        '未设置',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    const SettingsIcon(
                                      type: SettingsIconType.chevron,
                                    ),
                                  ],
                                ),
                                onTap: () => _open(
                                  GroupAnnouncementPage(
                                    controller: widget.controller,
                                    groupId: _conversation.id,
                                  ),
                                ),
                              ),
                              if (_canManage) _row('群管理', _openManagement),
                              remark,
                              _projectRow(),
                            ]),
                            const SizedBox(height: 12),
                            _section([
                              _row(
                                '查找聊天记录',
                                () => _open(
                                  GroupMessageSearchPage(
                                    controller: widget.controller,
                                    conversationId: _conversation.id,
                                  ),
                                ),
                              ),
                              GroupPinnedMessageEntry(
                                controller: widget.controller,
                                groupId: _conversation.id,
                                embedded: true,
                              ),
                            ]),
                            if (!_conversation.isArchived) ...[
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
                            const SizedBox(height: 12),
                            _surface(identity),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      DialogActionButton(
                        text: '退出群聊',
                        role: DialogActionRole.reject,
                        onPressed: _busy ? null : _leave,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _section(List<Widget> rows) => _surface(Column(children: rows));

  Widget _surface(Widget child) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff262626)
        : Colors.white,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _memberAction(String label, Widget icon, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: settingsFieldColor(context),
                  shape: BoxShape.circle,
                ),
                child: CustomPaint(
                  painter: _MemberActionOutline(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _member(MessageSender sender, {int remaining = 0}) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: remaining > 0
          ? () => _open(
              GroupActivityPage(
                controller: widget.controller,
                conversationId: _conversation.id,
              ),
            )
          : null,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (remaining > 0)
                MemberAvatar(sender: sender, size: 48)
              else
                MemberProfileAvatar(
                  controller: widget.controller,
                  sender: sender,
                  groupId: _conversation.id,
                  size: 48,
                ),
              if (remaining > 0)
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .48),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            remaining > 0 ? '更多成员' : sender.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
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

class _MemberActionOutline extends CustomPainter {
  const _MemberActionOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      canvas.drawArc(
        (Offset.zero & size).deflate(1),
        i * math.pi / 6,
        math.pi / 11,
        false,
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_MemberActionOutline oldDelegate) =>
      color != oldDelegate.color;
}
