import '../domain/contact_name_order.dart';
import '../features/chat/app_sheet_surface.dart';
import '../features/chat/chat_header_background.dart';
import '../domain/message_sender.dart';
import '../storage/development_projects.dart';
import '../features/chat/group_picker_tile.dart';
import '../features/chat/project_list_tile.dart';
import '../features/chat/member_selection_mark.dart';
import 'package:flutter/material.dart';
import '../domain/resource_scope.dart';
import '../features/chat/floating_search_layout.dart';
import '../features/chat/group_member_choice.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/search_type_segment.dart';
import '../widgets/empty_data_view.dart';
import 'skill_store.dart';

class SkillVisibilityTargets extends StatefulWidget {
  const SkillVisibilityTargets({
    super.key,
    required this.store,
    required this.groupAvatars,
    required this.selected,
    required this.scopes,
  });
  final SkillStore store;
  final Map<String, List<MessageSender>> groupAvatars;
  final Set<String> selected;
  final List<ResourceScope> scopes;
  @override
  State<SkillVisibilityTargets> createState() => _SkillVisibilityTargetsState();
}

class _SkillVisibilityTargetsState extends State<SkillVisibilityTargets> {
  late final _members = {...widget.selected};
  late final _scopes = widget.scopes.toSet();
  final _search = TextEditingController();
  int _category = 0;
  static const _labels = ['成员', '群聊', '项目'];

  void _changeCategory(int value) {
    setState(() {
      _category = value;
      _search.clear();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final members = widget.store.members
        .where(
          (m) =>
              m.id != widget.store.ownerId &&
              m.name.toLowerCase().contains(query),
        )
        .byContactName((member) => member);
    final groups = widget.store.groups
        .where((g) => (g['title'] as String).toLowerCase().contains(query))
        .toList();
    final projects = widget.store.projects
        .where((p) => (p['name'] as String).toLowerCase().contains(query))
        .toList();
    return AppSheetSurface(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: SafeArea(
            top: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: FloatingSearchLayout(
                    key: ValueKey(_category),
                    itemCount: switch (_category) {
                      0 =>
                        widget.store.members
                            .where((m) => m.id != widget.store.ownerId)
                            .length,
                      1 => widget.store.groups.length,
                      _ => widget.store.projects.length,
                    },
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    hintText: '搜索${_labels[_category]}',
                    enabled: true,
                    bottom: 16,
                    child:
                        [
                          members.isEmpty,
                          groups.isEmpty,
                          projects.isEmpty,
                        ][_category]
                        ? Center(
                            child: EmptyDataView(
                              title: query.isEmpty
                                  ? '暂无可选${_labels[_category]}'
                                  : '没有匹配的${_labels[_category]}',
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              68,
                              16,
                              FloatingSearchLayout.clearance,
                            ),
                            children: [
                              if (_category == 0)
                                for (final member in members)
                                  GroupMemberChoice(
                                    sender: member,
                                    selected: _members.contains(member.id),
                                    onTap: () => setState(() {
                                      if (!_members.remove(member.id))
                                        _members.add(member.id);
                                    }),
                                  ),
                              if (_category == 1)
                                for (final group in groups) _groupTile(group),
                              if (_category == 2)
                                for (final project in projects)
                                  _projectTile(
                                    DevelopmentProject.fromRow(project),
                                  ),
                            ],
                          ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 76,
                  child: IgnorePointer(child: ChatHeaderBackground()),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        RoundAction(
                          label: '关闭',
                          icon: Icons.close_rounded,
                          iconWidget: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: SearchTypeSegment.indexed(
                              labels: _labels,
                              index: _category,
                              onChanged: _changeCategory,
                            ),
                          ),
                        ),
                        RoundAction(
                          label: '完成',
                          icon: Icons.check_rounded,
                          iconWidget: SettingsIcon(
                            type: SettingsIconType.check,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(
                                  alpha: _members.isEmpty && _scopes.isEmpty
                                      ? .3
                                      : 1,
                                ),
                          ),
                          onPressed: _members.isEmpty && _scopes.isEmpty
                              ? null
                              : () => Navigator.pop(context, (
                                  _members,
                                  _scopes.toList(),
                                )),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(ResourceScope scope) => setState(() {
    if (!_scopes.remove(scope)) _scopes.add(scope);
  });

  Widget _groupTile(Map<String, Object?> group) {
    final id = group['id'] as String;
    final scope = ResourceScope.group(id);
    final selected = _scopes.contains(scope);
    return Semantics(
      checked: selected,
      child: GroupPickerTile(
        groupId: id,
        title: group['title'] as String,
        members: widget.groupAvatars[id] ?? const [],
        prefix: MemberSelectionMark(selected: selected),
        onTap: () => _toggle(scope),
      ),
    );
  }

  Widget _projectTile(DevelopmentProject project) {
    final scope = ResourceScope.project(project.id);
    final selected = _scopes.contains(scope);
    return Semantics(
      checked: selected,
      child: ProjectListTile(
        project: project,
        prefix: MemberSelectionMark(selected: selected),
        onTap: () => _toggle(scope),
      ),
    );
  }
}
