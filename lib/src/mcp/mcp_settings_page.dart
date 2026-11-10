import 'package:flutter/material.dart';
import '../app/glass_notice.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'mcp_connection_page.dart';
import 'mcp_settings.dart';

class McpSettingsPage extends StatefulWidget {
  const McpSettingsPage({super.key});
  @override
  State<McpSettingsPage> createState() => _McpSettingsPageState();
}

class _McpSettingsPageState extends State<McpSettingsPage> {
  final _settings = McpSettings.instance;
  bool _loaded = false, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _settings.load();
      if (mounted) setState(() => _loaded = true);
    } on Object catch (error) {
      if (mounted) {
        AppToasts.show(
          SnackBar(content: Text(error.toString())),
          kind: ToastKind.error,
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _enable(McpConnection connection, bool enabled) async {
    setState(() => _busy = true);
    try {
      await _settings.save(connection.withEnabled(enabled));
    } on Object catch (error) {
      if (mounted)
        AppToasts.show(
          SnackBar(content: Text(error.toString())),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit([McpConnection? connection]) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => McpConnectionPage(connection: connection),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(title: 'MCP', onBack: () => Navigator.pop(context)),
    floatingActionButton: FloatingActionButton(
      tooltip: '添加连接',
      onPressed: _loaded && !_busy ? () => _edit() : null,
      child: const SettingsIcon(type: SettingsIconType.add),
    ),
    body: SettingsPageBody(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: !_loaded
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListenableBuilder(
                  listenable: _settings,
                  builder: (context, _) => ListView(
                    padding: settingsPagePadding(
                      context,
                      const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    ),
                    children: [
                      Text(
                        '连接外部应用，让 AI 调用它们提供的工具。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (_settings.connections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            '还没有 MCP 连接，点击右下角添加。',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final connection in _settings.connections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(26),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(
                                18,
                                10,
                                12,
                                10,
                              ),
                              title: Text(connection.name),
                              subtitle: Text('${connection.url}\n允许 AI 使用'),
                              isThreeLine: true,
                              onTap: _busy ? null : () => _edit(connection),
                              trailing: Switch.adaptive(
                                value: connection.enabled,
                                onChanged: _busy
                                    ? null
                                    : (value) => _enable(connection, value),
                              ),
                            ),
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
