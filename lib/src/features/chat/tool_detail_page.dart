import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/tool_models.dart';
import 'settings_appearance.dart';
import 'tool_action_icon.dart';
import 'tool_payload_section.dart';

class ToolDetailPage extends StatelessWidget {
  const ToolDetailPage({super.key, required this.tool});
  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: toolTitle(tool.name),
      onBack: () => Navigator.pop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _surface(
                context,
                Row(
                  children: [
                    ToolActionIcon(toolName: tool.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        toolTitle(tool.name),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _label(context, '使用说明'),
              _surface(
                context,
                SelectableText(
                  tool.description,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              ToolPayloadSection(
                title: '调用参数',
                headerPadding: const EdgeInsets.fromLTRB(18, 14, 8, 2),
                titleStyle: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                json: jsonEncode(tool.modelInputSchema),
                missing: '无参数',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _surface(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
    ),
    child: child,
  );
}
