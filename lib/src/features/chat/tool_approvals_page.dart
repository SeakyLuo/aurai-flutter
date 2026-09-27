import 'dart:convert';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/tool_models.dart';
import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tool_action_icon.dart';
import 'tool_detail_page.dart';

class ToolApprovalsPage extends StatefulWidget {
  const ToolApprovalsPage({super.key, required this.controller});

  final ChatController controller;

  @override
  State<ToolApprovalsPage> createState() => _ToolApprovalsPageState();
}

class _ToolApprovalsPageState extends State<ToolApprovalsPage> {
  final _removing = <String>{};
  late final String _conversation = widget.controller.activeConversation.id;

  Future<void> _revoke(String key, String? conversation) async {
    final token = '$conversation:$key';
    setState(() => _removing.add(token));
    try {
      await widget.controller.toolApprovals.revoke(
        key,
        conversation: conversation,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('已撤销工具授权')));
      }
    } catch (caughtError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('撤销授权失败，请重试：${errorMessage(caughtError)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(token));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.toolApprovals;
    final current = store.sessions[_conversation] ?? {};
    final hasApprovals = store.persistent.isNotEmpty || current.isNotEmpty;
    final tools = {
      for (final tool in widget.controller.globalToolDefinitions)
        tool.name: tool,
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '工具授权',
        onBack: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: hasApprovals
                ? ListView(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      settingsHeaderHeight(context) + 16,
                      12,
                      24,
                    ),
                    children: [
                      const _PageIntroduction(),
                      if (store.persistent.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _ApprovalSection(
                          title: '始终允许',
                          description: '这些工具可在所有会话中直接执行',
                          entries: store.persistent,
                          tools: tools,
                          removing: _removing,
                          onRevoke: (key) => _revoke(key, null),
                          onOpen: _openTool,
                        ),
                      ],
                      if (current.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _ApprovalSection(
                          title: '当前会话允许',
                          description: '这些工具仅可在当前会话中直接执行',
                          entries: current,
                          tools: tools,
                          scope: _conversation,
                          removing: _removing,
                          onRevoke: (key) => _revoke(key, _conversation),
                          onOpen: _openTool,
                        ),
                      ],
                    ],
                  )
                : const _EmptyApprovals(),
          ),
        ),
      ),
    );
  }

  Future<void> _openTool(ToolDefinition tool) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ToolDetailPage(tool: tool)),
    );
    if (mounted) setState(() {});
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction();

  @override
  Widget build(BuildContext context) => Text(
    '已保存的授权会让 AI 在执行对应工具时不再重复询问。你可以随时撤销，之后再次执行时会重新确认。',
    style: TextStyle(
      fontSize: 14,
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ApprovalSection extends StatelessWidget {
  const _ApprovalSection({
    required this.title,
    required this.description,
    required this.entries,
    required this.tools,
    required this.removing,
    required this.onRevoke,
    required this.onOpen,
    this.scope,
  });

  final String title;
  final String description;
  final Map<String, String> entries;
  final Map<String, ToolDefinition> tools;
  final Set<String> removing;
  final ValueChanged<String> onRevoke;
  final ValueChanged<ToolDefinition> onOpen;
  final String? scope;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final entry in entries.entries) ...[
        _ApprovalTile(
          toolKey: entry.key,
          label: entry.value,
          tool: tools[_toolNameFromKey(entry.key)],
          removing: removing.contains('$scope:${entry.key}'),
          onRevoke: () => onRevoke(entry.key),
          onOpen: onOpen,
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.toolKey,
    required this.label,
    required this.tool,
    required this.removing,
    required this.onRevoke,
    required this.onOpen,
  });

  final String toolKey;
  final String label;
  final ToolDefinition? tool;
  final bool removing;
  final VoidCallback onRevoke;
  final ValueChanged<ToolDefinition> onOpen;

  String get _toolName => _toolNameFromKey(toolKey);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GlassSurface(
        radius: 24,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: tool == null ? null : () => onOpen(tool!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withValues(alpha: .22),
                          colors.primary.withValues(alpha: .08),
                        ],
                      ),
                    ),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xffc4b5fd)
                                : const Color(0xff7959df),
                            BlendMode.srcIn,
                          ),
                          child: FittedBox(
                            child: ToolActionIcon(toolName: _toolName),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (tool != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            tool!.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (removing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: onRevoke,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        backgroundColor: colors.error.withValues(alpha: .07),
                        minimumSize: const Size(48, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('撤销'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _toolNameFromKey(String key) =>
    key.startsWith('[') ? (jsonDecode(key) as List).first as String : key;

class _EmptyApprovals extends StatelessWidget {
  const _EmptyApprovals();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(32, settingsHeaderHeight(context), 32, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: settingsFieldColor(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SettingsIcon(
                  type: SettingsIconType.permission,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '暂无已保存的授权',
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '需要确认的操作仍会在执行前询问你，授权后会显示在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
