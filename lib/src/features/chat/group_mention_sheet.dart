import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import '../../domain/ai_profile.dart';
import 'sidebar_action_icon.dart';

Future<List<MessageSender>?> showGroupMentionSheet(
  BuildContext context,
  GroupChatStore store,
  String conversationId,
) => showModalBottomSheet<List<MessageSender>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _MentionSheet(store: store, conversationId: conversationId),
);

class _MentionSheet extends StatefulWidget {
  const _MentionSheet({required this.store, required this.conversationId});
  final GroupChatStore store;
  final String conversationId;
  @override
  State<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends State<_MentionSheet> {
  final _search = TextEditingController();
  List<ConversationMember>? _members;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.store.members(widget.conversationId);
      if (mounted)
        setState(
          () => _members = members
              .where((m) => m.sender.kind == MessageSenderKind.agent)
              .toList(),
        );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('成员读取失败，请重试：${errorMessage(error)}')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height * .72 -
            MediaQuery.viewInsetsOf(context).bottom * .5,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48),
                      child: Center(
                        child: Text(
                          '选择提醒的人',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SettingsGlassAction(
                        label: '关闭',
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索成员',
                    filled: true,
                    fillColor: settingsFieldColor(context),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(14),
                      child: SidebarActionIcon(
                        type: SidebarActionIconType.search,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _members == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            minLeadingWidth: 44,
                            horizontalTitleGap: 12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            leading: const SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: SidebarActionIcon(
                                  type: SidebarActionIconType.group,
                                ),
                              ),
                            ),
                            title: const Text(
                              '所有人',
                              style: TextStyle(fontSize: 15),
                            ),
                            onTap: () =>
                                Navigator.pop(context, <MessageSender>[]),
                          ),
                          for (final member in _members!.where(
                            (m) => m.sender.name.toLowerCase().contains(query),
                          ))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              minLeadingWidth: 44,
                              horizontalTitleGap: 12,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              leading: MemberAvatar(
                                sender: member.sender,
                                size: 44,
                              ),
                              title: Text(
                                member.sender.name,
                                style: const TextStyle(fontSize: 15),
                              ),
                              onTap: () =>
                                  Navigator.pop(context, [member.sender]),
                            ),
                          if (query.isNotEmpty &&
                              !_members!.any(
                                (m) =>
                                    m.sender.name.toLowerCase().contains(query),
                              ))
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('没有找到成员')),
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
