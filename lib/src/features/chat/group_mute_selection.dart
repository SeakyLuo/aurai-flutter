import 'floating_search_layout.dart';
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
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final _searchController = TextEditingController();

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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('已选择 ${_selected.length} 位'),
                ),
              ),
              Expanded(
                child: FloatingSearchLayout(
                  itemCount: widget.members.length,
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                  hintText: '搜索群成员',
                  controller: _searchController,
                  enabled: true,
                  bottom: 16,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          FloatingSearchLayout.clearance,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverList.list(
                              children: [
                                for (final member in visible)
                                  GroupMemberChoice(
                                    selected: _selected.contains(
                                      member.sender.id,
                                    ),
                                    sender: member.sender,
                                    onTap: () => setState(() {
                                      if (!_selected.remove(member.sender.id))
                                        _selected.add(member.sender.id);
                                    }),
                                  ),
                              ],
                            ),
                            if (visible.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: const Padding(
                                    padding: EdgeInsets.all(32),
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
            ],
          ),
        ),
      ),
    );
  }
}
