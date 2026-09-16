import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import 'skill_store.dart';
import 'skill_list_tile.dart';

class SkillDependencyPicker extends StatefulWidget {
  const SkillDependencyPicker({
    super.key,
    required this.store,
    required this.skillId,
    required this.selected,
  });
  final SkillStore store;
  final String skillId;
  final Set<String> selected;
  @override
  State<SkillDependencyPicker> createState() => _SkillDependencyPickerState();
}

class _SkillDependencyPickerState extends State<SkillDependencyPicker> {
  late final _selected = Set<String>.of(widget.selected);
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '依赖技能',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '确定',
          icon: Icons.check_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.check),
          onPressed: () => Navigator.pop(context, _selected),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
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
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.store,
                  builder: (context, _) {
                    final query = _search.text.toLowerCase();
                    final items = widget.store.library
                        .where(
                          (s) =>
                              s.id != widget.skillId &&
                              (s.name.toLowerCase().contains(query) ||
                                  s.description.toLowerCase().contains(query)),
                        )
                        .toList();
                    if (items.isEmpty)
                      return Center(
                        child: Text(query.isEmpty ? '没有其他技能可选' : '没有找到匹配的技能'),
                      );
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final skill = items[index];
                        final selected = _selected.contains(skill.id);
                        void toggle() => setState(() {
                          if (selected) {
                            _selected.remove(skill.id);
                          } else {
                            _selected.add(skill.id);
                          }
                        });
                        return Semantics(
                          checked: selected,
                          child: SkillListTile(
                            skill: skill,
                            showDisabled: true,
                            onTap: toggle,
                            titleTrailing: Checkbox(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              value: selected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: (_) => toggle(),
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
