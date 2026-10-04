import 'package:flutter/material.dart';
import 'floating_search_layout.dart';
import '../../domain/message_sender.dart';
import 'group_member_choice.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'question_icon.dart';

enum DraftVisibilityMode { everyone, included, excluded }

class DraftVisibility {
  const DraftVisibility(this.mode, this.members, {this.selections = const {}});
  final DraftVisibilityMode mode;
  final List<MessageSender> members;
  final Map<DraftVisibilityMode, List<MessageSender>> selections;
  List<String>? get audience => mode == DraftVisibilityMode.included
      ? [MessageSender.localUser.id, ...members.map((m) => m.id)]
      : null;
  List<String>? get excludedAudience => mode == DraftVisibilityMode.excluded
      ? members.map((m) => m.id).toList()
      : null;
  String get label => mode == DraftVisibilityMode.everyone
      ? '所有人可见'
      : mode == DraftVisibilityMode.included
      ? members.isEmpty
            ? '仅自己可见'
            : '仅 ' + members.map((m) => m.name).join('、') + ' 可见'
      : members.map((m) => m.name).join('、') + ' 不可见';
}

class DraftVisibilitySheet extends StatefulWidget {
  const DraftVisibilitySheet({
    super.key,
    required this.mode,
    required this.members,
    this.initial,
  });
  final DraftVisibilityMode mode;
  final List<MessageSender> members;
  final DraftVisibility? initial;
  @override
  State<DraftVisibilitySheet> createState() => _DraftVisibilitySheetState();
}

class _DraftVisibilitySheetState extends State<DraftVisibilitySheet> {
  late final _selected = <String>{
    ...?widget.initial?.members.map((m) => m.id),
    if (widget.mode == DraftVisibilityMode.included) MessageSender.localUser.id,
  };
  String _search = '';
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: SearchSheetBody(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.mode == DraftVisibilityMode.included
                        ? '选择可见成员'
                        : '选择不可见成员',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                SettingsGlassAction(
                  label: '完成',
                  icon: Icons.check_rounded,
                  iconWidget: const SettingsIcon(type: SettingsIconType.check),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          DraftVisibility(
                            widget.mode,
                            widget.members
                                .where(
                                  (m) =>
                                      m.id != MessageSender.localUser.id &&
                                      _selected.contains(m.id),
                                )
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          child: FloatingSearchLayout(
            itemCount: widget.members.length,
            controller: _input,
            hintText: '搜索群成员',
            onChanged: (text) =>
                setState(() => _search = text.trim().toLowerCase()),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    FloatingSearchLayout.clearance,
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverList.list(
                        children: [
                          const SizedBox(height: 12),

                          const SizedBox(height: 8),
                          for (final member in widget.members.where(
                            (m) => m.name.toLowerCase().contains(_search),
                          ))
                            GroupMemberChoice(
                              selected: _selected.contains(member.id),
                              sender: member,
                              onTap: member.id == MessageSender.localUser.id
                                  ? null
                                  : () => setState(() {
                                      if (!_selected.remove(member.id))
                                        _selected.add(member.id);
                                    }),
                            ),
                        ],
                      ),
                      if (!widget.members.any(
                        (m) => m.name.toLowerCase().contains(_search),
                      ))
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '没有找到匹配的成员',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
