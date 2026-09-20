import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'ai_contact_page.dart';
import '../../domain/message_sender.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';

class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({
    super.key,
    required this.controller,
    required this.conversationId,
  });
  final ChatController controller;
  final String conversationId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  List<ConversationMember> _members = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final members = await widget.controller.groupStore.members(
        widget.conversationId,
      );
      if (mounted) setState(() => _members = members);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('群成员加载失败，请重试：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      gradientBackground: true,
      title: _members.isEmpty ? '群成员' : '群成员（${_members.length}）',
      onBack: () => Navigator.pop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? Center(
                  child: TextButton(onPressed: _load, child: const Text('重试')),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    View.of(context).padding.top /
                            View.of(context).devicePixelRatio +
                        76 +
                        12,
                    16,
                    24,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100,
                    mainAxisExtent: 96,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final sender = _members[index].sender;
                    return Tooltip(
                      message: sender.name,
                      child: GestureDetector(
                        onTap: sender.kind == MessageSenderKind.agent
                            ? () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AiContactPage(
                                      controller: widget.controller,
                                      senderId: sender.id,
                                      groupId: widget.conversationId,
                                    ),
                                  ),
                                );
                                if (mounted) _load();
                              }
                            : null,
                        child: Column(
                          children: [
                            MemberAvatar(sender: sender, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              sender.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}
