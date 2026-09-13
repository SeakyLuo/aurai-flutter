import 'skill_list_tile.dart';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import '../features/chat/question_icon.dart';
import '../scheduling/task_filter_menu.dart';
import 'skill_editor.dart';
import 'skill_store.dart';
import 'skill_action_menu.dart';
import 'skill_permission_picker.dart';
import 'skill_sort_picker.dart';
import '../scheduling/task_action_menu.dart';
import '../features/chat/delete_confirmation_dialog.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key, required this.store});
  final SkillStore store;
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final _titleKey = GlobalKey();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _filter = 'enabled';
  bool _menuOpen = false;
  String get _title => _filter == 'enabled' ? '已启用技能' : '已停用技能';

  Future<void> _chooseFilter() async {
    final box = _titleKey.currentContext!.findRenderObject()! as RenderBox;
    setState(() => _menuOpen = true);
    final selected = await showTaskChoiceMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: _filter,
      label: '技能筛选',
      centerOnAnchor: true,
      choices: const [
        (value: 'enabled', label: '已启用'),
        (value: 'disabled', label: '已停用'),
      ],
    );
    if (!mounted) return;
    setState(() {
      _menuOpen = false;
      if (selected != null) _filter = selected;
    });
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _preferences(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    final action = await showSkillPreferencesMenu(
      context,
      box.localToGlobal(Offset(0, box.size.height)),
    );
    if (!mounted || action == null) return;
    if (action == 'sort') {
      final selected = await showSkillSortPicker(context, widget.store.sort);
      if (!mounted || selected == null) return;
      try {
        await widget.store.saveSort(selected);
      } on Object {
        if (mounted) _notice('保存排序失败，请重试');
      }
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
      if (mounted) _notice('偏好权限已保存');
    } on Object {
      if (mounted) _notice('保存失败，请重试');
    }
  }

  Future<void> _skillMenu(SavedSkill skill, Offset position) async {
    final action = await showSkillActionMenu(
      context,
      position,
      skill.enabled,
      showEdit: true,
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SkillEditor(store: widget.store, skill: skill),
        ),
      );
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => const DeleteConfirmationDialog(
          title: '删除技能？',
          description: '删除后，Aurai 将无法再查找和调用这个技能。',
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    try {
      if (action == 'delete') {
        await widget.store.delete(skill.name);
      } else {
        await widget.store.save(
          SavedSkill.fromJson({
            ...skill.toJson(),
            'enabled': action == 'resume',
          }),
          previousName: skill.name,
        );
      }
      if (mounted)
        _notice(
          action == 'delete'
              ? '技能已删除'
              : action == 'resume'
              ? '技能已启用'
              : '技能已停用',
        );
    } on Object catch (error) {
      if (mounted) _notice(error is StateError ? error.message : '操作失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '技能',
      onBack: () => Navigator.pop(context),
      actions: [
        Builder(
          builder: (buttonContext) => SettingsGlassAction(
            label: '更多',
            icon: Icons.more_vert,
            iconWidget: const TaskActionIcon('more'),
            onPressed: () => _preferences(buttonContext),
          ),
        ),
      ],
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('技能'),
          Semantics(
            button: true,
            label: '$_title，筛选技能',
            child: GestureDetector(
              key: _titleKey,
              behavior: HitTestBehavior.opaque,
              onTap: _chooseFilter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 3, 12, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _filter == 'enabled' ? '已启用' : '已停用',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _menuOpen ? -.25 : .25,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: SizedBox.square(
                        dimension: 14,
                        child: FittedBox(
                          child: SettingsIcon(
                            type: SettingsIconType.chevron,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '搜索技能',
                    filled: true,
                    fillColor: settingsFieldColor(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
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
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () => setState(_search.clear),
                            icon: const QuestionIcon(
                              type: QuestionIconType.close,
                            ),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.store,
                  builder: (context, _) {
                    final query = _search.text.trim().toLowerCase();
                    final skills =
                        widget.store.skills
                            .where(
                              (skill) =>
                                  skill.enabled == (_filter == 'enabled'),
                            )
                            .where(
                              (skill) =>
                                  query.isEmpty ||
                                  skill.name.toLowerCase().contains(query) ||
                                  skill.description.toLowerCase().contains(
                                    query,
                                  ),
                            )
                            .toList()
                          ..sort(widget.store.compareSkills);
                    if (skills.isEmpty) {
                      return Center(
                        child: Text(
                          query.isEmpty ? '暂无$_title' : '没有匹配的技能',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      itemCount: skills.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final skill = skills[index];
                        return SkillListTile(
                          skill: skill,
                          onLongPressStart: (details) =>
                              _skillMenu(skill, details.globalPosition),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SkillEditor(
                                store: widget.store,
                                skill: skill,
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
