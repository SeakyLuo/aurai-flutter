import 'dialog_action_button.dart';
import 'tool_approvals_page.dart';
import 'ai_contact_actions.dart';
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
    } on Object {
      if (mounted) {
        _notice('朋友读取失败');
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
    await openAiChat(context, widget.controller, _ai!);
    if (mounted && widget.groupId != null) {
      try {
        await widget.controller.selectConversation(widget.groupId!);
      } on Object {
        if (mounted) _notice('返回群聊失败，请重新打开群聊');
      }
    }
    if (mounted) setState(() => _busy = false);
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
              } on Object {
                if (mounted) _notice('记忆读取失败');
              }
            },
          ),
        ),
      );
    } on Object {
      if (mounted) _notice('记忆读取失败');
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
    } catch (_) {
      if (mounted) _notice('添加失败，请重试');
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
                    if (mounted) await _page(SkillsPage(store: store));
                  } on Object {
                    if (mounted) _notice('技能读取失败，请重试');
                  }
                }),
                _row(
                  '工具授权',
                  SettingsIconType.tools,
                  () => _page(
                    ToolApprovalsPage(
                      controller: widget.controller,
                      senderId: widget.senderId,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                WidgetUtils.primaryButton(
                  text: ai.sender.archived
                      ? '恢复朋友'
                      : ai.isTemporary
                      ? '添加朋友'
                      : '发消息',
                  onPressed: _busy
                      ? null
                      : ai.sender.archived
                      ? _archive
                      : ai.isTemporary
                      ? _addFriend
                      : _message,
                ),
                if (!ai.sender.archived && !ai.isTemporary) ...[
                  const SizedBox(height: 12),
                  DialogActionButton(
                    text: '归档朋友',
                    role: DialogActionRole.secondary,
                    onPressed: _busy ? null : _archive,
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
