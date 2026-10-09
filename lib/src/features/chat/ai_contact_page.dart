import 'subagent_detail_page.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import '../../domain/contact_display_names.dart';
import 'contact_remark_action.dart';
import 'friend_notification.dart';
import '../../storage/group_member_details.dart';
import '../../storage/home_conversations.dart';
import 'header_action_menu.dart';
import 'conversation_menu_icon.dart';
import 'tool_approvals_page.dart';
import 'ai_contact_actions.dart';
import 'ai_conversations_page.dart';
import 'home_navigation.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/profile_gender.dart';
import '../../domain/ai_profile.dart';
import '../../domain/avatar_style.dart';
import '../../memory/memory_summary_page.dart';
import '../../skills/skills_page.dart';
import '../../utils/widget_utils.dart';
import 'chat_controller.dart';
import 'ai_contact_editor.dart';
import 'ai_model_page.dart';
import 'ai_speech_page.dart';
import 'profile_avatar.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class AiContactPage extends StatefulWidget {
  const AiContactPage({
    super.key,
    required this.controller,
    required this.senderId,
    this.groupId,
  });
  final ChatController controller;
  final String senderId;
  final String? groupId;
  @override
  State<AiContactPage> createState() => _AiContactPageState();
}

class _AiContactPageState extends State<AiContactPage> {
  AiProfile? _ai;
  String _groupNickname = '';
  bool _busy = false;
  bool _isFriend = false;
  int _unreadCompletedTasks = 0;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _notice(String text, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(text)), kind: kind);
  Future<void> _reload() async {
    try {
      final groupId = widget.groupId;
      final (ai, nickname, friendship, completedTasks) = await (
        widget.controller.groupStore.loadAi(widget.senderId),
        groupId == null
            ? Future.value('')
            : GroupMemberDetailsStore(widget.controller.groupStore.database)
                  .read(groupId, senderId: widget.senderId)
                  .then((details) => details.nickname),
        widget.controller.groupStore.database.query(
          'contact_friendships',
          columns: ['friend_id'],
          where: "owner_id = 'user:local' AND friend_id = ?",
          whereArgs: [widget.senderId],
          limit: 1,
        ),
        HomeConversations(
          widget.controller.groupStore,
        ).unreadCompletionsForAi(widget.senderId),
      ).wait;
      if (mounted) {
        setState(() {
          _ai = ai;
          _groupNickname = nickname;
          _isFriend = friendship.isNotEmpty;
          _unreadCompletedTasks = completedTasks;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        _notice('朋友读取失败：${errorMessage(error)}', kind: ToastKind.error);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _page(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) _reload();
  }

  Future<void> _message() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await widget.controller.openAiConversation(_ai!);
      if (!mounted) return;
      await openHomeConversation(
        context,
        widget.controller,
        id,
        waitForClose: true,
      );
    } on Object catch (error) {
      if (mounted)
        _notice('无法打开私聊，请稍后重试：${errorMessage(error)}', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _memory() async {
    try {
      final memory = await widget.controller.aiMemory(_ai!);
      if (!mounted) return;
      await _page(
        MemorySummaryPage(
          memory: memory,
          onOpenSource: (source) async {
            if (source['parent_run_id'] != null) {
              await _page(
                SubagentDetailPage(
                  controller: widget.controller,
                  runId: source['run_id'] as String,
                ),
              );
            } else {
              await openHomeConversation(
                context,
                widget.controller,
                source['conversation_id'] as String,
                messageId: source['focus_message_id'] as String?,
                waitForClose: true,
              );
            }
          },
        ),
      );
    } on Object catch (error) {
      if (mounted)
        _notice('记忆读取失败：${errorMessage(error)}', kind: ToastKind.error);
    }
  }

  Future<void> _archive() async {
    await changeAiArchive(context, widget.controller, _ai!);
    if (mounted) await _reload();
  }

  Future<void> _remark() async {
    setState(() => _busy = true);
    try {
      await editContactRemark(context, widget.controller, widget.senderId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFriend() async {
    setState(() => _busy = true);
    try {
      final notifyFriend = await showDialog<bool>(
        context: context,
        builder: (_) => AddFriendDialog(name: _ai!.sender.displayName),
      );
      if (notifyFriend == null || !mounted) return;
      await widget.controller.addAiFriend(
        _ai!.copyWith(isTemporary: false),
        notifyFriend: notifyFriend,
      );
      await _reload();
      if (mounted) _notice('已添加到通讯录', kind: ToastKind.success);
    } catch (caughtError) {
      if (mounted)
        _notice('添加失败，请重试：${errorMessage(caughtError)}', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _ai;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '',
        titleWidget: const SizedBox.shrink(),
        onBack: () => Navigator.pop(context),
        actions: [
          if (ai != null)
            Builder(
              builder: (buttonContext) => SettingsGlassAction(
                label: '更多',
                icon: Icons.more_vert_rounded,
                onPressed: _busy
                    ? null
                    : () async {
                        final action = await showHeaderActionMenu(
                          buttonContext,
                          destructiveValues: const {'archive'},
                          items: [
                            (
                              value: 'edit',
                              label: '编辑',
                              icon: ConversationMenuIcon(
                                type: ConversationMenuIconType.rename,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (_isFriend)
                              (
                                value: 'remark',
                                label: '设置备注名',
                                icon: SettingsIcon(
                                  type: SettingsIconType.note,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            if (!ai.sender.archived &&
                                _isFriend &&
                                ai.sender.id != MessageSender.aurai.id)
                              (
                                value: 'archive',
                                label: '归档朋友',
                                icon: ConversationMenuIcon(
                                  type: ConversationMenuIconType.archive,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        );
                        if (!mounted) return;
                        if (action == 'edit') {
                          await _page(
                            AiContactEditor(
                              controller: widget.controller,
                              profile: ai,
                            ),
                          );
                        } else if (action == 'remark') {
                          await _remark();
                        } else if (action == 'archive') {
                          await _archive();
                        }
                      },
              ),
            ),
        ],
      ),
      body: SettingsPageBody(
        child: ai == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  settingsHeaderHeight(context) -
                      (SettingsAppBar.toolbarHeight - RoundAction.defaultSize) /
                          2,
                  16,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        ProfileAvatar(
                          style: AvatarStyle(
                            icon: ai.sender.avatarIcon,
                            color: ai.sender.avatarColor,
                            path: ai.sender.avatarPath,
                          ),
                          name: ai.sender.name,
                        ),
                        if (ai.preferences.gender != ProfileGender.unknown)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GlassSurface(
                              radius: 12,
                              tintOpacity: .5,
                              shadowOpacity: .3,
                              child: SizedBox.square(
                                dimension: 24,
                                child: Center(
                                  child: Text(
                                    ai.preferences.gender == ProfileGender.male
                                        ? '♂'
                                        : '♀',
                                    semanticsLabel: ai.preferences.gender.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          ai.preferences.gender ==
                                              ProfileGender.male
                                          ? GlobalUI.maleColor
                                          : GlobalUI.femaleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ai.sender.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (ContactDisplayNames.remark(ai.sender.id) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '名字：${ai.sender.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_groupNickname.isNotEmpty &&
                      _groupNickname != ai.sender.name)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '群昵称：$_groupNickname',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (ai.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        ai.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _row(
                    '个人资料',
                    SettingsIconType.personalInfo,
                    () => _page(
                      AiContactEditor(
                        controller: widget.controller,
                        profile: ai,
                      ),
                    ),
                  ),
                  _row(
                    '模型',
                    SettingsIconType.model,
                    () => _page(
                      AiModelPage(controller: widget.controller, profile: ai),
                    ),
                    subtitle: widget.controller.aiConfig(ai).model,
                  ),
                  _row(
                    '声音',
                    SettingsIconType.sound,
                    () => _page(
                      AiSpeechPage(controller: widget.controller, profile: ai),
                    ),
                  ),
                  _row('记忆', SettingsIconType.memory, _memory),
                  _row('技能', SettingsIconType.skills, () async {
                    try {
                      final store = await widget.controller.aiSkills(
                        widget.senderId,
                      );
                      if (mounted)
                        await _page(
                          SkillsPage(
                            store: store,
                            controller: widget.controller,
                          ),
                        );
                    } on Object catch (error) {
                      if (mounted)
                        _notice(
                          '技能读取失败，请重试：${errorMessage(error)}',
                          kind: ToastKind.error,
                        );
                    }
                  }),
                  _row(
                    '工具授权',
                    SettingsIconType.permission,
                    () => _page(
                      ToolApprovalsPage(
                        controller: widget.controller,
                        senderId: ai.sender.id,
                      ),
                    ),
                  ),
                  if (!ai.sender.archived && _isFriend)
                    _row(
                      '任务',
                      SettingsIconType.job,
                      () => _page(
                        AiConversationsPage(
                          controller: widget.controller,
                          profile: ai,
                        ),
                      ),
                      value: _unreadCompletedTasks == 0
                          ? null
                          : '$_unreadCompletedTasks 项已完成',
                    ),
                  const SizedBox(height: 24),
                  WidgetUtils.primaryButton(
                    text: ai.sender.archived
                        ? '恢复朋友'
                        : !_isFriend
                        ? '添加朋友'
                        : '发消息',
                    onPressed: !ai.sender.archived && _isFriend
                        ? _message
                        : _busy
                        ? null
                        : ai.sender.archived
                        ? _archive
                        : _addFriend,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _row(
    String title,
    SettingsIconType icon,
    VoidCallback onTap, {
    String? subtitle,
    String? value,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: SettingsIcon(type: icon),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
        onTap: onTap,
      ),
    ),
  );
}
