import 'package:flutter/material.dart';
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
  const SkillsPage({super.key, required this.store, this.library = false});
  final SkillStore store;
  final bool library;
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final _search = TextEditingController();
  String _status = 'all';
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
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
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
      builder: (_) => SkillsPage(store: widget.store, library: true),
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
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: widget.library ? '技能库' : '技能',
      titleWidget: SkillPageHeader(
        library: widget.library,
        scope: _filter,
        status: _status,
        onScope: (value) => setState(() => _filter = value),
        onStatus: (value) => setState(() => _status = value),
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
                    final query = _search.text.trim().toLowerCase();
                    final items =
                        widget.store.library
                            .where(
                              (s) =>
                                  (_filter != 'installed' ||
                                      widget.store.isInstalled(s.id)) &&
                                  (_filter != 'installed' ||
                                      _status == 'all' ||
                                      s.enabled == (_status == 'enabled')) &&
                                  (_filter != 'created' ||
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
                                  : _filter == 'installed'
                                  ? (_status == 'all'
                                        ? '还没有安装技能'
                                        : _status == 'enabled'
                                        ? '暂无已启用技能'
                                        : '暂无已停用技能')
                                  : '暂无技能',
                            ),
                            if (query.isEmpty && _filter == 'installed') ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _status == 'all'
                                    ? _install
                                    : () => setState(() => _status = 'all'),
                                child: Text(
                                  _status == 'all' ? '去安装' : '查看全部已安装技能',
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
                        return SkillListTile(
                          skill: skill,
                          subtitlePrefix: widget.store.ownerName(skill),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SkillDetailPage(
                                store: widget.store,
                                skillId: skill.id,
                              ),
                            ),
                          ),
                          titleTrailing: !widget.store.usesInstallations
                              ? null
                              : Text(
                                  widget.store.isInstalled(skill.id)
                                      ? (skill.enabled ? '已启用' : '已停用')
                                      : '未安装',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
