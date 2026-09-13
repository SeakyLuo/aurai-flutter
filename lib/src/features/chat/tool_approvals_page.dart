import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';

class ToolApprovalsPage extends StatefulWidget {
  const ToolApprovalsPage({super.key, required this.controller, this.senderId});
  final ChatController controller;
  final String? senderId;
  @override
  State<ToolApprovalsPage> createState() => _ToolApprovalsPageState();
}

class _ToolApprovalsPageState extends State<ToolApprovalsPage> {
  final _removing = <String>{};

  Future<void> _revoke(String key, String? conversation) async {
    final token = '$conversation:$key';
    setState(() => _removing.add(token));
    try {
      await widget.controller.toolApprovals.revoke(
        key,
        conversation: conversation,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('撤销授权失败，请重试')));
    } finally {
      if (mounted) setState(() => _removing.remove(token));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.toolApprovals;
    final conversation = widget.controller.activeConversation.id;
    bool included(String key) =>
        widget.senderId == null ||
        (widget.senderId == 'agent:aurai'
            ? !key.startsWith('agent:')
            : key.startsWith('${widget.senderId}:'));
    Map<String, String> only(Map<String, String> entries) =>
        Map.fromEntries(entries.entries.where((entry) => included(entry.key)));
    final current = only(store.sessions[conversation] ?? {});
    Widget section(String title, Map<String, String> entries, String? scope) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              child: Text(title),
            ),
            if (entries.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('暂无授权')),
            for (final entry in entries.entries)
              ListTile(
                title: Text(entry.value),
                trailing: TextButton(
                  onPressed: _removing.contains('$scope:${entry.key}')
                      ? null
                      : () => _revoke(entry.key, scope),
                  child: const Text('撤销'),
                ),
              ),
          ],
        );
    return Scaffold(
      appBar: SettingsAppBar(
        title: '工具授权',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          section('始终允许', only(store.persistent), null),
          if (widget.senderId == null)
            section('当前会话允许', current, conversation)
          else
            for (final entry in store.sessions.entries)
              if (only(entry.value).isNotEmpty)
                section('会话授权', only(entry.value), entry.key),
        ],
      ),
    );
  }
}
