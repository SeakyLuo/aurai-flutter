import 'dart:convert';
import 'package:flutter/material.dart';
import '../../platform/aurai_platform.dart';
import '../../domain/interactive_message.dart';
import '../../domain/error_message.dart';
import '../../storage/group_message_search.dart';
import 'attachment_action_icon.dart';
import 'chat_controller.dart';
import 'interactive_message_view.dart';
import 'settings_appearance.dart';

class GroupSearchCardPage extends StatefulWidget {
  const GroupSearchCardPage({
    super.key,
    required this.result,
    required this.controller,
    required this.onLocate,
  });
  final GroupMessageSearchResult result;
  final ChatController controller;
  final VoidCallback onLocate;
  @override
  State<GroupSearchCardPage> createState() => _GroupSearchCardPageState();
}

class _GroupSearchCardPageState extends State<GroupSearchCardPage> {
  InteractiveMessage? _card;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await widget.controller.groupStore.database.query(
        'messages',
        columns: ['interactive_json'],
        where: 'id = ? AND kind != ?',
        whereArgs: [widget.result.id, 'system'],
      );
      if (rows.isEmpty) throw StateError('消息已删除或撤回');
      final card = InteractiveMessage.fromJson(
        jsonDecode(rows.single['interactive_json'] as String)
            as Map<String, dynamic>,
      );
      if (mounted) setState(() => _card = card);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(title: '交互消息', onBack: () => Navigator.pop(context)),
    body: _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : _card == null
        ? Center(
            child: TextButton(onPressed: _reload, child: const Text('重新打开')),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.result.sender.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              InteractiveMessageView(
                card: _card!,
                onClick: (button, revision) async {
                  final url = await widget.controller.clickInteractiveMessage(
                    widget.result.id,
                    button,
                    revision,
                  );
                  await _reload();
                  return url;
                },
                onOpenLink: (url) async {
                  try {
                    await AuraiPlatform.instance.startIntent({
                      'action': 'android.intent.action.VIEW',
                      'data': url,
                    });
                  } on Object catch (error) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMessage(error))),
                      );
                  }
                },
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: widget.onLocate,
                icon: const AttachmentActionIcon(
                  type: AttachmentActionIconType.locate,
                ),
                label: const Text('定位原消息'),
              ),
            ],
          ),
  );
}
