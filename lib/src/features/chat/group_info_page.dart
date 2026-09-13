import 'dart:math' as math;
import 'dialog_action_button.dart';
import 'group_invite_page.dart';
import 'group_remove_members_page.dart';
import 'package:flutter/material.dart';

import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/conversation_rows.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'conversation_rename_dialog.dart';
import 'conversation_task_navigation.dart';
import 'group_members_page.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({
    super.key,
    required this.controller,
    required this.conversation,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
    this.originTaskId,
  });

  final ChatController controller;
  final Conversation conversation;
  final Future<void> Function() onPin;
  final Future<void> Function() onArchive;
  final Future<void> Function() onDelete;
  final String? originTaskId;

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late Conversation _conversation = widget.conversation;
  List<ConversationMember> _members = [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

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
        ),
        widget.controller.groupStore.members(widget.conversation.id),
      ]);
      if (!mounted) return;
      final rows = results[0] as List<Map<String, Object?>>;
      if (rows.isEmpty || (leaveArchived && rows.single['archived'] == 1)) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _conversation = conversationFromRow(rows.single);
        _members = results[1] as List<ConversationMember>;
        _failed = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('群聊信息加载失败，请重试')));
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _surface(
                        Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minTileHeight: 60,
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
                                GroupMembersPage(
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
                                builder: (context, constraints) => GridView(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            constraints.maxWidth < 320 ? 4 : 5,
                                        mainAxisExtent:
                                            62 +
                                            MediaQuery.textScalerOf(
                                              context,
                                            ).scale(17),
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 8,
                                      ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    for (final member in _members.take(10))
                                      _member(member.sender),
                                    _memberAction(
                                      '邀请',
                                      const SettingsIcon(
                                        type: SettingsIconType.add,
                                      ),
                                      () => _open(
                                        GroupInvitePage(
                                          controller: widget.controller,
                                          conversationId: _conversation.id,
                                          members: _members,
                                        ),
                                      ),
                                    ),
                                    _memberAction(
                                      '移除',
                                      const _RemoveMemberIcon(),
                                      () => _open(
                                        GroupRemoveMembersPage(
                                          controller: widget.controller,
                                          conversationId: _conversation.id,
                                          members: _members,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _surface(
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          minTileHeight: 60,
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
                      if (!_conversation.isArchived) ...[
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
                      if (conversationTasks(
                        widget.controller,
                        _conversation.id,
                        originTaskId: widget.originTaskId,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _surface(
                          _row(
                            '关联任务',
                            () => openConversationTask(
                              context,
                              widget.controller,
                              _conversation.id,
                              originTaskId: widget.originTaskId,
                            ),
                            icon: const SettingsIcon(
                              type: SettingsIconType.tasks,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DialogActionButton(
                        text: _conversation.isArchived ? '取消归档' : '归档群聊',
                        role: DialogActionRole.secondary,
                        onPressed: _busy
                            ? null
                            : () => _perform(
                                widget.onArchive,
                                leaveArchived: !_conversation.isArchived,
                              ),
                      ),
                      const SizedBox(height: 12),
                      DialogActionButton(
                        text: '删除群聊',
                        role: DialogActionRole.reject,
                        onPressed: _busy
                            ? null
                            : () => _perform(widget.onDelete),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

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

  Widget _member(MessageSender sender) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: sender.kind == MessageSenderKind.agent
          ? () => _open(
              AiContactPage(
                controller: widget.controller,
                senderId: sender.id,
                groupId: _conversation.id,
              ),
            )
          : null,
      child: Column(
        children: [
          MemberAvatar(sender: sender, size: 48),
          const SizedBox(height: 7),
          Text(
            sender.name,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    minTileHeight: 60,
    leading: icon,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: const SettingsIcon(type: SettingsIconType.chevron),
    onTap: onTap,
  );
}

class _RemoveMemberIcon extends StatelessWidget {
  const _RemoveMemberIcon();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 16,
      height: 1.65,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
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
