import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import 'group_member_choice.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMuteSelection extends StatefulWidget {
  const GroupMuteSelection({
    super.key,
    required this.members,
    required this.chooseDuration,
  });
  final List<ConversationMember> members;
  final Future<({Duration? duration})?> Function(
    BuildContext context,
    int count,
  )
  chooseDuration;
  @override
  State<GroupMuteSelection> createState() => _GroupMuteSelectionState();
}

class _GroupMuteSelectionState extends State<GroupMuteSelection> {
  final _selected = <String>{};
  String _search = '';
  bool _choosing = false;
  Future<void> _next() async {
    setState(() => _choosing = true);
    final choice = await widget.chooseDuration(context, _selected.length);
    if (!mounted) return;
    setState(() => _choosing = false);
    if (choice != null)
      Navigator.pop(context, (members: _selected, duration: choice.duration));
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.members.where(
      (m) => m.sender.name.toLowerCase().contains(_search),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '选择禁言成员',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '下一步',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _selected.isEmpty || _choosing ? null : _next,
          ),
        ],
      ),
      body: SettingsPageBody(
        avoidHeader: true,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索群成员',
                    filled: true,
                    fillColor: settingsFieldColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('已选择 ${_selected.length} 位'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final member in visible)
                      GroupMemberChoice(
                        selected: _selected.contains(member.sender.id),
                        sender: member.sender,
                        onTap: () => setState(() {
                          if (!_selected.remove(member.sender.id))
                            _selected.add(member.sender.id);
                        }),
                      ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('没有找到匹配的成员', textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
