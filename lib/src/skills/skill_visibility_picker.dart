import '../app/glass_notice.dart';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'skill_store.dart';

String skillVisibilityLabel(String value) => switch (value) {
  'public' => '公开',
  'selected' => '指定人 / AI 可见',
  _ => '仅自己可见',
};

class SkillVisibilityPicker extends StatefulWidget {
  const SkillVisibilityPicker({
    super.key,
    required this.store,
    required this.visibility,
    required this.selected,
  });
  final SkillStore store;
  final String visibility;
  final Set<String> selected;
  @override
  State<SkillVisibilityPicker> createState() => _SkillVisibilityPickerState();
}

class _SkillVisibilityPickerState extends State<SkillVisibilityPicker> {
  late String _visibility = widget.visibility;
  late final _selected = {...widget.selected};
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '可见范围',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '确定',
          icon: Icons.check_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.check),
          onPressed: () {
            if (_visibility == 'selected' && _selected.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showGlassSnackBar(const SnackBar(content: Text('请选择可见的人或 AI')));
              return;
            }
            Navigator.pop(context, (_visibility, _selected));
          },
        ),
      ],
    ),
    body: SettingsPageBody(
      child: SafeArea(
        child: ListView(
          padding: settingsPagePadding(context, const EdgeInsets.all(16)),
          children: [
            for (final value in ['private', 'public', 'selected'])
              ListTile(
                title: Text(skillVisibilityLabel(value)),
                subtitle: Text(switch (value) {
                  'public' => '所有人和 AI 可查看、安装、修改和删除',
                  'selected' => '选中的人和 AI 可查看、安装，内容由你维护',
                  _ => '只有自己可查看、安装和维护',
                }),
                trailing: _visibility == value
                    ? const SettingsIcon(type: SettingsIconType.check)
                    : null,
                onTap: () => setState(() => _visibility = value),
              ),
            if (_visibility == 'selected') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索联系人',
                  filled: true,
                  fillColor: settingsFieldColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final member in widget.store.members.where(
                (m) =>
                    m.id != widget.store.ownerId &&
                    m.name.toLowerCase().contains(
                      _search.text.trim().toLowerCase(),
                    ),
              ))
                CheckboxListTile(
                  title: Text(member.name),
                  value: _selected.contains(member.id),
                  onChanged: (value) => setState(() {
                    value!
                        ? _selected.add(member.id)
                        : _selected.remove(member.id);
                  }),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
