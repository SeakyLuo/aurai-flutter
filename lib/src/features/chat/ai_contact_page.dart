import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import 'dialog_action_button.dart';
import 'header_action_menu.dart';
import 'conversation_menu_icon.dart';
import 'tool_approvals_page.dart';
import 'ai_contact_actions.dart';
import 'ai_conversations_page.dart';
import 'home_navigation.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/avatar_style.dart';
import '../../memory/memory_summary_page.dart';
import '../../skills/skills_page.dart';
import '../../utils/widget_utils.dart';
import 'chat_controller.dart';
import 'ai_contact_editor.dart';
import 'ai_model_page.dart';
import 'ai_group_picker.dart';
import 'profile_avatar.dart';
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
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _reload() async {
    try {
      final ai = await widget.controller.groupStore.loadAi(widget.senderId);
      if (mounted) setState(() => _ai = ai);
    } on Object catch (error) {
      if (mounted) {
        _notice('朋友读取失败：${errorMessage(error)}');
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
      if (mounted) _notice('无法打开私聊，请稍后重试：${errorMessage(error)}');
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
          initialGroup: widget.groupId != null,
          groupMemories: AiGroupList(
            controller: widget.controller,
            senderId: widget.senderId,
            onSelected: (group) async {
              try {
                final memory = await widget.controller.aiMemory(
                  _ai!,
                  scope: group['id'] as String,
                );
                if (mounted)
                  await _page(
                    MemorySummaryPage(
                      memory: memory,
                      title: group['title'] as String,
                    ),
                  );
              } on Object catch (error) {
                if (mounted) _notice('记忆读取失败：${errorMessage(error)}');
              }
            },
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) _notice('记忆读取失败：${errorMessage(error)}');
    }
  }

  Future<void> _archive() async {
    await changeAiArchive(context, widget.controller, _ai!);
    if (mounted) await _reload();
  }

  Future<void> _addFriend() async {
    setState(() => _busy = true);
    try {
      await widget.controller.saveAi(_ai!.copyWith(isTemporary: false));
      await _reload();
      if (mounted) _notice('已添加到通讯录');
    } catch (caughtError) {
      if (mounted) _notice('添加失败，请重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _ai;
    return Scaffold(
      appBar: SettingsAppBar(
        title: '朋友',
        onBack: () => Navigator.pop(context),
        actions: [
          if (ai != null)
            Builder(
              builder: (buttonContext) => SettingsGlassAction(
                label: '更多',
                icon: Icons.more_horiz_rounded,
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
                            if (!ai.sender.archived &&
                                !ai.isTemporary &&
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
                        } else if (action == 'archive') {
                          await _archive();
                        }
                      },
              ),
            ),
        ],
      ),
      body: ai == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Center(
                  child: ProfileAvatar(
                    style: AvatarStyle(
                      icon: ai.sender.avatarIcon,
                      color: ai.sender.avatarColor,
                      path: ai.sender.avatarPath,
                    ),
                    name: ai.sender.name,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ai.sender.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
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
                    AiContactEditor(controller: widget.controller, profile: ai),
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
                _row('记忆', SettingsIconType.memory, _memory),
                _row('技能', SettingsIconType.skills, () async {
                  try {
                    final store = await widget.controller.aiSkills(
                      widget.senderId,
                    );
                    if (mounted)
                      await _page(
                        SkillsPage(store: store, controller: widget.controller),
                      );
                  } on Object catch (error) {
                    if (mounted) _notice('技能读取失败，请重试：${errorMessage(error)}');
                  }
                }),
                _row(
                  '工具授权',
                  SettingsIconType.tools,
                  () => _page(ToolApprovalsPage(controller: widget.controller)),
                ),
                const SizedBox(height: 24),
                WidgetUtils.primaryButton(
                  text: ai.sender.archived
                      ? '恢复朋友'
                      : ai.isTemporary
                      ? '添加朋友'
                      : '发消息',
                  onPressed: !ai.sender.archived && !ai.isTemporary
                      ? _message
                      : _busy
                      ? null
                      : ai.sender.archived
                      ? _archive
                      : _addFriend,
                ),
                if (!ai.sender.archived && !ai.isTemporary) ...[
                  const SizedBox(height: 12),
                  DialogActionButton(
                    text: '会话列表',
                    role: DialogActionRole.secondary,
                    onPressed: _busy
                        ? null
                        : () => _page(
                            AiConversationsPage(
                              controller: widget.controller,
                              profile: ai,
                              openEmptyConversation: false,
                            ),
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _row(
    String title,
    SettingsIconType icon,
    VoidCallback onTap, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: SettingsIcon(type: icon),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const SettingsIcon(type: SettingsIconType.chevron),
        onTap: onTap,
      ),
    ),
  );
}
