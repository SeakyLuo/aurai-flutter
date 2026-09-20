import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';

class ToolApprovalsPage extends StatefulWidget {
  const ToolApprovalsPage({super.key, required this.controller});
  final ChatController controller;
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
    } catch (caughtError) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('撤销授权失败，请重试：${errorMessage(caughtError)}')),
        );
    } finally {
      if (mounted) setState(() => _removing.remove(token));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.toolApprovals;
    final conversation = widget.controller.activeConversation.id;
    final current = store.sessions[conversation] ?? {};
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
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        gradientBackground: true,
        title: '工具授权',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          View.of(context).padding.top / View.of(context).devicePixelRatio +
              76 +
              0,
          18,
          0,
        ),
        children: [
          section('始终允许', store.persistent, null),
          section('当前会话允许', current, conversation),
        ],
      ),
    );
  }
}
