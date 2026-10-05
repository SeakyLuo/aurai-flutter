import '../features/chat/floating_search_layout.dart';
import 'package:flutter/material.dart';
import '../domain/message_sender.dart';
import '../features/chat/group_member_choice.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/visibility_option_tile.dart';
import '../widgets/empty_data_view.dart';
import 'skill_store.dart';
import '../domain/resource_scope.dart';
import '../features/chat/resource_scope_picker.dart';

String skillVisibilityLabel(
  String value, {
  List<ResourceScope> scopes = const [],
}) => switch (value) {
  'public' => scopes.isEmpty ? '所有人可见' : '部分可见',
  'partial' => '部分可见',
  'selected' => '指定人可见',
  _ => '仅自己可见',
};

Future<(String, Set<String>, List<ResourceScope>)?> showSkillVisibilityPicker(
  BuildContext context, {
  required SkillStore store,
  required String visibility,
  required Set<String> selected,
  required List<ResourceScope> scopes,
}) => showModalBottomSheet<(String, Set<String>, List<ResourceScope>)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => SkillVisibilityPicker(
    store: store,
    visibility: visibility,
    selected: selected,
    scopes: scopes,
  ),
);

class SkillVisibilityPicker extends StatefulWidget {
  const SkillVisibilityPicker({
    super.key,
    required this.store,
    required this.visibility,
    required this.selected,
    required this.scopes,
  });
  final SkillStore store;
  final String visibility;
  final Set<String> selected;
  final List<ResourceScope> scopes;
  @override
  State<SkillVisibilityPicker> createState() => _SkillVisibilityPickerState();
}

class _SkillVisibilityPickerState extends State<SkillVisibilityPicker> {
  late String _visibility =
      widget.visibility == 'public' && widget.scopes.isNotEmpty
      ? 'partial'
      : widget.visibility;
  late List<ResourceScope> _scopes = [...widget.scopes];

  Future<void> _chooseScopes() async {
    final scopes = await showModalBottomSheet<List<ResourceScope>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: ResourceScopePicker(
          groups: widget.store.groups,
          projects: widget.store.projects,
          selected: _scopes,
          requiredGroup: true,
        ),
      ),
    );
    if (!mounted || scopes == null) return;
    setState(() {
      _scopes = scopes;
      _visibility = 'partial';
    });
  }

  late Set<String> _selected = {...widget.selected};

  Future<void> _chooseMembers() async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _SkillVisibleMembersSheet(
          members: widget.store.members
              .where((m) => m.id != widget.store.ownerId)
              .toList(),
          selected: _selected,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _visibility = 'selected';
      _selected = selected;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VisibilityHeader(
            title: '技能可见范围',
            actionLabel: '保存',
            onDone:
                (_visibility == 'selected' && _selected.isEmpty) ||
                    (_visibility == 'partial' && _scopes.isEmpty)
                ? null
                : () => Navigator.pop(context, (
                    _visibility == 'partial' ? 'public' : _visibility,
                    _selected,
                    _visibility == 'public' ? <ResourceScope>[] : _scopes,
                  )),
          ),
          const SizedBox(height: 12),
          for (final value in ['public', 'partial', 'private', 'selected'])
            VisibilityOptionTile(
              selected: _visibility == value,
              opensMembers: value == 'selected' || value == 'partial',
              title: skillVisibilityLabel(value),
              subtitle: value == 'partial'
                  ? (_scopes.isEmpty
                        ? '选择群聊或项目'
                        : resourceScopeLabel(
                            _scopes,
                            widget.store.groups,
                            widget.store.projects,
                          ))
                  : value == 'selected' && _selected.isNotEmpty
                  ? widget.store.members
                        .where((m) => _selected.contains(m.id))
                        .map((m) => m.name)
                        .join('、')
                  : switch (value) {
                      'public' => '所有人均可查看和使用',
                      'selected' => '选中的人可查看、安装，内容由你维护',
                      _ => '只有自己可查看、安装和维护',
                    },
              onTap: value == 'partial'
                  ? _chooseScopes
                  : value == 'selected'
                  ? _chooseMembers
                  : () => setState(() => _visibility = value),
            ),
        ],
      ),
    ),
  );
}

class _SkillVisibleMembersSheet extends StatefulWidget {
  const _SkillVisibleMembersSheet({
    required this.members,
    required this.selected,
  });
  final List<MessageSender> members;
  final Set<String> selected;
  @override
  State<_SkillVisibleMembersSheet> createState() =>
      _SkillVisibleMembersSheetState();
}

class _SkillVisibleMembersSheetState extends State<_SkillVisibleMembersSheet> {
  late final _selected = {...widget.selected};
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final members = widget.members
        .where((m) => m.name.toLowerCase().contains(query))
        .toList();
    return FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: SearchSheetBody(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _VisibilityHeader(
              title: '选择可见成员',
              onDone: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected),
            ),
          ),
          child: FloatingSearchLayout(
            itemCount: widget.members.length,
            controller: _search,
            onChanged: (_) => setState(() {}),
            hintText: '搜索联系人',
            enabled: true,
            bottom: 16,
            child: members.isEmpty
                ? Center(
                    child: EmptyDataView(
                      title: widget.members.isEmpty ? '暂无可选联系人' : '没有找到匹配的成员',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      68,
                      20,
                      FloatingSearchLayout.clearance,
                    ),
                    itemCount: members.length,
                    itemBuilder: (_, index) {
                      final member = members[index];
                      return GroupMemberChoice(
                        selected: _selected.contains(member.id),
                        sender: member,
                        onTap: () => setState(() {
                          if (!_selected.remove(member.id))
                            _selected.add(member.id);
                        }),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityHeader extends StatelessWidget {
  const _VisibilityHeader({
    required this.title,
    required this.onDone,
    this.actionLabel = '完成',
  });
  final String title;
  final VoidCallback? onDone;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SettingsGlassAction(
            label: '关闭',
            icon: Icons.close_rounded,
            iconWidget: const QuestionIcon(type: QuestionIconType.close),
            onPressed: () => Navigator.pop(context),
          ),
          SettingsGlassAction(
            label: actionLabel,
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: onDone,
          ),
        ],
      ),
    ],
  );
}
