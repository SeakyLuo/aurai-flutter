import '../app/glass_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/ai_contact_page.dart';
import '../domain/message_sender.dart';
import '../features/chat/member_avatar.dart';
import '../domain/error_message.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/dialog_action_button.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_action_menu.dart';
import 'skill_action_menu.dart';
import 'skill_editor.dart';
import 'skill_icon.dart';
import 'skill_permission_picker.dart';
import 'skill_store.dart';
import 'skill_visibility_picker.dart';

class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({
    super.key,
    required this.store,
    required this.controller,
    required this.skillId,
  });
  final SkillStore store;
  final ChatController controller;
  final String skillId;
  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  bool _busy = false;
  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));
  Future<void> _copyName(String name) async {
    await Clipboard.setData(ClipboardData(text: name));
    if (mounted) _notice('技能名称已复制');
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _notice(success);
    } on Object catch (e) {
      if (mounted) _notice(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(SavedSkill skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteConfirmationDialog(
        title: '从技能库删除？',
        description: '技能将从所有人的安装列表中移除，此操作无法撤销。',
      ),
    );
    if (!mounted || confirmed != true) return;
    await _act(() async {
      await widget.store.delete(skill.id);
      if (mounted) Navigator.pop(context);
    }, '技能已删除');
  }

  Future<void> _menu(BuildContext anchor, SavedSkill skill) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final action = await showSkillActionMenu(
      context,
      box.localToGlobal(Offset(0, box.size.height)),
      skill.enabled,
      showEdit: widget.store.canEdit(skill),
      canDelete: widget.store.canEdit(skill),
      installed:
          widget.store.usesInstallations && widget.store.isInstalled(skill.id),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SkillEditor(
              store: widget.store,
              skill: widget.store.readId(skill.id),
            ),
          ),
        );
      case 'uninstall':
        await _act(() => widget.store.uninstall(skill.id), '技能已卸载');
      case 'pause' || 'resume':
        await _act(
          () => widget.store.setEnabled(skill.id, action == 'resume'),
          action == 'resume' ? '技能已启用' : '技能已停用',
        );
      case 'delete':
        await _delete(skill);
    }
  }

  Widget _section(String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SelectableText(text),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final skill = widget.store.library
          .where((s) => s.id == widget.skillId)
          .firstOrNull;
      if (skill == null) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: SettingsAppBar(
            title: '技能详情',
            onBack: () => Navigator.pop(context),
          ),
          body: SettingsPageBody(
            avoidHeader: true,
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回技能列表'),
              ),
            ),
          ),
        );
      }
      final installed = widget.store.isInstalled(skill.id);
      final creator = widget.store.members
          .where((member) => member.id == skill.ownerId)
          .firstOrNull;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '技能详情',
          onBack: () => Navigator.pop(context),
          actions: [
            if (widget.store.canEdit(skill) ||
                (widget.store.usesInstallations && installed))
              Builder(
                builder: (anchor) => SettingsGlassAction(
                  label: '更多',
                  icon: Icons.more_vert,
                  iconWidget: const TaskActionIcon('more'),
                  onPressed: _busy ? null : () => _menu(anchor, skill),
                ),
              ),
          ],
        ),
        body: SettingsPageBody(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.all(20),
                  ),
                  children: [
                    Row(
                      children: [
                        SkillIcon(skill.icon),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _copyName(skill.name),
                            child: Text(
                              skill.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(skill.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (creator != null) ...[
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: creator.kind != MessageSenderKind.agent
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => AiContactPage(
                                          controller: widget.controller,
                                          senderId: creator.id,
                                        ),
                                      ),
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: MemberAvatar(sender: creator, size: 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            widget.store.ownerName(skill),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          skillVisibilityLabel(skill.visibility),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (widget.store.usesInstallations && !installed)
                      DialogActionButton(
                        text: '安装技能',
                        role: DialogActionRole.primary,
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => widget.store.install(skill.id),
                                '技能已安装',
                              ),
                      ),
                    if (widget.store.usesInstallations && installed) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('调用权限'),
                        subtitle: Text(
                          widget.store.permissionFor(skill.id).label,
                        ),
                        trailing: const SettingsIcon(
                          type: SettingsIconType.chevron,
                        ),
                        onTap: _busy
                            ? null
                            : () async {
                                final choice = await showSkillPermissionPicker(
                                  context,
                                  widget.store.permissionOverrideFor(
                                        skill.id,
                                      ) ??
                                      widget.store.defaultPermission,
                                );
                                if (mounted && choice != null)
                                  await _act(
                                    () => widget.store.setPermission(
                                      skill.id,
                                      choice.permission,
                                    ),
                                    '权限已保存',
                                  );
                              },
                      ),
                    ],
                    _section('使用说明', skill.instructions),
                    if (skill.script.isNotEmpty) _section('执行脚本', skill.script),
                    if (skill.dependencyIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('依赖技能'),
                      for (final id in skill.dependencyIds) _dependency(id),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _dependency(String id) {
    final skill = widget.store.library.where((s) => s.id == id).firstOrNull;
    if (skill == null)
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('依赖技能不可见'),
        subtitle: Text('请联系创建者调整可见范围'),
      );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(skill.name),
      subtitle: !widget.store.usesInstallations
          ? null
          : Text(
              widget.store.isInstalled(id)
                  ? (skill.enabled ? '已安装' : '已停用')
                  : '未安装',
            ),
      trailing: const SettingsIcon(type: SettingsIconType.chevron),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SkillDetailPage(
            store: widget.store,
            controller: widget.controller,
            skillId: id,
          ),
        ),
      ),
    );
  }
}
