import '../app/glass_notice.dart';
import 'package:flutter/material.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/member_avatar.dart';
import 'skill_visibility_picker.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_filter_menu.dart';
import '../domain/error_message.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/sidebar_action_icon.dart';
import 'skill_detail_page.dart';
import 'skill_page_header.dart';
import 'skill_editor.dart';
import 'skill_list_tile.dart';
import 'skill_store.dart';
import 'skill_sort_picker.dart';
import 'skill_permission_picker.dart';
import 'skill_action_menu.dart';
import '../scheduling/task_action_menu.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({
    super.key,
    required this.store,
    required this.controller,
    this.library = false,
  });
  final SkillStore store;
  final ChatController controller;
  final bool library;
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final _search = TextEditingController();
  String _status = 'enabled';
  late String _filter = widget.library ? 'library' : 'installed';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.store.reload();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SkillEditor(
        store: widget.store,
        skill: const SavedSkill(
          name: '',
          description: '',
          instructions: '',
          script: '',
          enabled: true,
          revision: 0,
        ),
      ),
    ),
  );
  Future<void> _install() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SkillsPage(
        store: widget.store,
        controller: widget.controller,
        library: true,
      ),
    ),
  );
  Future<void> _sort() async {
    final value = await showSkillSortPicker(context, widget.store.sort);
    if (value == null || !mounted) return;
    try {
      await widget.store.saveSort(value);
    } on Object catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  bool _acting = false;
  Future<void> _skillMenu(SavedSkill skill, Offset position) async {
    if (_acting) return;
    final installed =
        widget.store.usesInstallations && widget.store.isInstalled(skill.id);
    final editable = widget.store.canEdit(skill);
    final canInstall = widget.store.usesInstallations && !installed;
    if (!installed && !editable && !canInstall) return;
    final action = await showSkillActionMenu(
      context,
      position,
      skill.enabled,
      showEdit: editable,
      canDelete: editable,
      installed: installed,
      canInstall: canInstall,
    );
    if (!mounted || action == null) return;
    _acting = true;
    try {
      if (action == 'edit') {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SkillEditor(
              store: widget.store,
              skill: widget.store.readId(skill.id),
            ),
          ),
        );
        return;
      }
      if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => const DeleteConfirmationDialog(
            title: '从技能库删除？',
            description: '技能将从所有人的安装列表中移除，此操作无法撤销。',
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      final message = switch (action) {
        'install' => '技能已安装',
        'uninstall' => '技能已卸载',
        'pause' => '技能已停用',
        'resume' => '技能已启用',
        _ => '技能已删除',
      };
      switch (action) {
        case 'install':
          await widget.store.install(skill.id);
        case 'uninstall':
          await widget.store.uninstall(skill.id);
        case 'pause' || 'resume':
          await widget.store.setEnabled(skill.id, action == 'resume');
        case 'delete':
          await widget.store.delete(skill.id);
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      _acting = false;
    }
  }

  Future<void> _chooseStatus(BuildContext anchor) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final box = anchor.findRenderObject()! as RenderBox;
    final selected = await showTaskChoiceMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: _status,
      label: '技能状态',
      choices: const [
        (value: 'enabled', label: '已启用'),
        (value: 'disabled', label: '已停用'),
      ],
    );
    if (mounted && selected != null) setState(() => _status = selected);
  }

  Future<void> _preferences(BuildContext anchor) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final action = await showSkillPreferencesMenu(
      context,
      box.localToGlobal(Offset(0, box.size.height)),
      library: widget.library,
      showPermissions: widget.store.usesInstallations,
    );
    if (!mounted || action == null) return;
    if (action == 'create') {
      await _create();
      return;
    }
    if (action == 'install') {
      await _install();
      return;
    }
    if (action == 'sort') {
      await _sort();
      return;
    }
    final selection = await showSkillPermissionPicker(
      context,
      widget.store.defaultPermission,
      defaults: true,
    );
    if (!mounted || selection == null) return;
    try {
      await widget.store.saveDefaultPermission(selection.permission!);
    } on Object catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: widget.library ? '技能库' : '技能',
      titleWidget: widget.library
          ? null
          : SkillPageHeader(
              scope: _filter,
              onScope: (value) => setState(() => _filter = value),
            ),
      onBack: () => Navigator.pop(context),
      actions: [
        Builder(
          builder: (anchor) => SettingsGlassAction(
            label: '更多',
            icon: Icons.more_vert,
            iconWidget: const TaskActionIcon('more'),
            onPressed: () => _preferences(anchor),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '搜索技能',
                    suffixIcon: _filter != 'installed'
                        ? null
                        : Builder(
                            builder: (anchor) => IconButton(
                              tooltip: switch (_status) {
                                'enabled' => '筛选：已启用',
                                'disabled' => '筛选：已停用',
                                _ => '筛选：已启用',
                              },
                              onPressed: () => _chooseStatus(anchor),
                              icon: Badge(
                                isLabelVisible: _status == 'disabled',
                                child: SettingsIcon(
                                  type: SettingsIconType.filter,
                                  color: _status == 'enabled'
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                    filled: true,
                    fillColor: settingsFieldColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(13),
                      child: SidebarActionIcon(
                        type: SidebarActionIconType.search,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.store,
                  builder: (context, _) {
                    if (_loading)
                      return const Center(child: CircularProgressIndicator());
                    final scope = widget.library ? 'library' : _filter;
                    final query = _search.text.trim().toLowerCase();
                    final items =
                        widget.store.library
                            .where(
                              (s) =>
                                  (scope != 'installed' ||
                                      widget.store.isInstalled(s.id)) &&
                                  (scope != 'installed' ||
                                      s.enabled == (_status == 'enabled')) &&
                                  (scope != 'created' ||
                                      s.ownerId == widget.store.ownerId) &&
                                  (s.name.toLowerCase().contains(query) ||
                                      s.description.toLowerCase().contains(
                                        query,
                                      )),
                            )
                            .toList()
                          ..sort(widget.store.compareSkills);
                    if (items.isEmpty)
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              query.isNotEmpty
                                  ? '没有匹配的技能'
                                  : scope == 'installed'
                                  ? switch (_status) {
                                      'enabled' => '暂无已启用技能',
                                      'disabled' => '暂无已停用技能',
                                      _ => '暂无已启用技能',
                                    }
                                  : '暂无技能',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (query.isEmpty && scope == 'installed') ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _status == 'enabled'
                                    ? _install
                                    : () => setState(() => _status = 'enabled'),
                                child: Text(
                                  _status == 'enabled' ? '去安装' : '查看已启用技能',
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final skill = items[index];
                        final creator = widget.store.members
                            .where((member) => member.id == skill.ownerId)
                            .firstOrNull;
                        return SkillListTile(
                          skill: skill,
                          onLongPressStart: (details) =>
                              _skillMenu(skill, details.globalPosition),
                          footer: !widget.library
                              ? null
                              : Row(
                                  children: [
                                    if (creator != null) ...[
                                      MemberAvatar(sender: creator, size: 24),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        widget.store.ownerName(skill),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      skillVisibilityLabel(skill.visibility),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SkillDetailPage(
                                controller: widget.controller,
                                store: widget.store,
                                skillId: skill.id,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
