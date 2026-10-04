import '../features/chat/library_detail_split.dart';
import '../features/chat/resource_scope_filter.dart';
import '../domain/resource_scope.dart';
import '../features/chat/floating_search_layout.dart';
import '../widgets/empty_data_view.dart';
import '../app/glass_notice.dart';
import 'package:flutter/material.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/member_avatar.dart';
import 'skill_visibility_picker.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/settings_icon.dart';
import '../domain/error_message.dart';
import '../features/chat/settings_appearance.dart';
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
    this.groupId,
    this.projectId,
  });
  final SkillStore store;
  final ChatController controller;
  final bool library;
  final String? groupId, projectId;
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final _detailSplitKey = GlobalKey<LibraryDetailSplitState>();
  int get _resourceCount => widget.store.library
      .where(
        (skill) =>
            matchesResourceFilter(
              skill.scopes,
              widget.groupId != null
                  ? ResourceScope.group(widget.groupId!)
                  : widget.projectId != null
                  ? ResourceScope.project(widget.projectId!)
                  : null,
              widget.store.groups,
            ) &&
            (widget.library ||
                _filter != 'installed' ||
                widget.store.isInstalled(skill.id)),
      )
      .length;
  final _search = TextEditingController();
  String _status = 'enabled';
  late ResourceScope? _scope = widget.groupId != null
      ? ResourceScope.group(widget.groupId!)
      : widget.projectId != null
      ? ResourceScope.project(widget.projectId!)
      : null;
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
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
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
        skill: SavedSkill(
          scopes: [if (_scope != null) _scope!],
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
        groupId: _scope?.type == 'group' ? _scope!.id : null,
        projectId: _scope?.type == 'project' ? _scope!.id : null,
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
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(e))),
          kind: ToastKind.error,
        );
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
        ).showToast(SnackBar(content: Text(message)), kind: ToastKind.success);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      _acting = false;
    }
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
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(e))),
          kind: ToastKind.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) => LibraryDetailSplit(
    key: _detailSplitKey,
    child: Scaffold(
      extendBodyBehindAppBar: true,
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
      body: SettingsPageBody(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Expanded(
                    child: FloatingSearchLayout(
                      itemCount: _resourceCount,
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      hintText: '搜索技能',
                      trailingAction: _resourceCount < 20
                          ? null
                          : ResourceScopeFilter(
                              groups: widget.store.groups,
                              projects: widget.store.projects,
                              value: _scope,
                              onChanged: (value) =>
                                  setState(() => _scope = value),
                              status: _status,
                              onStatus:
                                  !widget.library && _filter == 'installed'
                                  ? (value) => setState(() => _status = value)
                                  : null,
                            ),
                      enabled: true,
                      bottom: 16,
                      child: ListenableBuilder(
                        listenable: widget.store,
                        builder: (context, _) {
                          if (_loading)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          final scope = widget.library ? 'library' : _filter;
                          final query = _search.text.trim().toLowerCase();
                          final items =
                              widget.store.library
                                  .where(
                                    (s) =>
                                        matchesResourceFilter(
                                          s.scopes,
                                          _scope,
                                          widget.store.groups,
                                        ) &&
                                        (scope != 'installed' ||
                                            widget.store.isInstalled(s.id)) &&
                                        (scope != 'installed' ||
                                            s.enabled ==
                                                (_status == 'enabled')) &&
                                        (scope != 'created' ||
                                            s.ownerId ==
                                                widget.store.ownerId) &&
                                        (s.name.toLowerCase().contains(query) ||
                                            s.description
                                                .toLowerCase()
                                                .contains(query)),
                                  )
                                  .toList()
                                ..sort(widget.store.compareSkills);
                          if (items.isEmpty)
                            return Center(
                              child: EmptyDataView(
                                title: query.isNotEmpty
                                    ? '没有匹配的技能'
                                    : scope == 'installed'
                                    ? (_status == 'disabled'
                                          ? '暂无已停用技能'
                                          : '暂无已启用技能')
                                    : '暂无技能',
                                description:
                                    query.isEmpty &&
                                        scope == 'installed' &&
                                        _status == 'enabled'
                                    ? '安装并启用技能，让 AI 拥有更多能力，帮你处理各种任务。'
                                    : null,
                                actionText:
                                    query.isEmpty && scope == 'installed'
                                    ? (_status == 'enabled' ? '去安装' : '查看已启用技能')
                                    : null,
                                actionIcon: _status == 'enabled'
                                    ? SettingsIcon(
                                        type: SettingsIconType.add,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      )
                                    : null,
                                onAction: _status == 'enabled'
                                    ? _install
                                    : () => setState(() => _status = 'enabled'),
                              ),
                            );
                          return ListView.separated(
                            padding: settingsPagePadding(
                              context,
                              const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                FloatingSearchLayout.clearance,
                              ),
                            ),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
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
                                            MemberAvatar(
                                              sender: creator,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            child: Text(
                                              widget.store.ownerName(skill),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            skillVisibilityLabel(
                                              skill.visibility,
                                              scopes: skill.scopes,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                onTap: () => _detailSplitKey.currentState!.open(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SkillDetailPage(
                                      controller: widget.controller,
                                      store: widget.store,
                                      skillId: skill.id,
                                      groupId: _scope?.type == 'group'
                                          ? _scope!.id
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
