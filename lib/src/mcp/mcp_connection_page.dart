import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/glass_notice.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/dialog_action_button.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_text_field.dart';
import '../features/chat/provider_api_key_field.dart';
import '../scheduling/task_unsaved_dialog.dart';
import 'mcp_client.dart';
import 'mcp_settings.dart';

class McpConnectionPage extends StatefulWidget {
  const McpConnectionPage({super.key, this.connection});
  final McpConnection? connection;
  @override
  State<McpConnectionPage> createState() => _McpConnectionPageState();
}

class _McpConnectionPageState extends State<McpConnectionPage> {
  late final _original = widget.connection ?? McpConnection.create();
  late final _name = TextEditingController(text: _original.name);
  late final _url = TextEditingController(text: _original.url);
  late final _token = TextEditingController(text: _original.token);
  late bool _enabled = _original.enabled;
  bool _busy = false, _leaving = false;
  McpClient? _testing;
  McpConnection get _value => McpConnection(
    id: _original.id,
    name: _name.text.trim(),
    url: _url.text.trim(),
    token: _token.text,
    enabled: _enabled,
  );
  bool get _dirty =>
      jsonEncode(_value.toJson()) != jsonEncode(_original.toJson());
  @override
  void initState() {
    super.initState();
    for (final c in [_name, _url, _token]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    _cancelTest();
    setState(() {});
  }

  void _cancelTest() {
    final client = _testing;
    _testing = null;
    client?.close();
  }

  @override
  void dispose() {
    _cancelTest();
    for (final c in [_name, _url, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notice(String text, {ToastKind kind = ToastKind.error}) =>
      AppToasts.show(SnackBar(content: Text(text)), kind: kind);
  void _pop() {
    _cancelTest();
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    _cancelTest();
    setState(() => _busy = true);
    try {
      await McpSettings.instance.save(_value);
      if (mounted) _pop();
    } on Object catch (error) {
      if (mounted) _notice(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(_cancelTest);
    if (!_dirty) {
      _pop();
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: 'MCP 连接还有未保存的修改。'),
    );
    if (!mounted) return;
    if (result == 'save')
      await _save();
    else if (result == 'discard')
      _pop();
  }

  Future<void> _test() async {
    final client = McpClient(_value);
    setState(() => _testing = client);
    try {
      final result = await client.listTools();
      if (mounted && identical(_testing, client))
        _notice(
          '连接成功，已发现 ${(result['tools'] as List).length} 个工具${result['nextCursor'] == null ? '' : '，还有更多'}',
          kind: ToastKind.success,
        );
    } on Object catch (error) {
      if (mounted && identical(_testing, client)) _notice(error.toString());
    } finally {
      client.close();
      if (mounted && identical(_testing, client)) {
        setState(() => _testing = null);
      }
    }
  }

  Future<void> _delete() async {
    setState(_cancelTest);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '删除连接？',
        description: '删除“${_original.name}”的连接配置，不会删除外部应用的数据。',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await McpSettings.instance.remove(_original.id);
      if (mounted) _pop();
    } on Object catch (error) {
      if (mounted) _notice(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required String hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsFieldLabel(label),
        if (secret)
          ProviderApiKeyField(
            controller: controller,
            enabled: !_busy,
            credentialLabel: '令牌',
            decoration: settingsTextFieldDecoration(context, hint: hint),
          )
        else
          TextField(
            controller: controller,
            enabled: !_busy,
            autocorrect: label == '连接名称',
            enableSuggestions: label == '连接名称',
            keyboardType: label == '服务地址'
                ? TextInputType.url
                : TextInputType.text,
            style: const TextStyle(fontSize: 16),
            decoration: settingsTextFieldDecoration(context, hint: hint),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: widget.connection == null ? '添加 MCP 连接' : 'MCP 连接',
        onBack: _busy ? null : _leave,
        actions: [
          SettingsGlassActionSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundAction(
                  label: '测试连接',
                  icon: Icons.link,
                  iconWidget: _testing != null
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SettingsIcon(type: SettingsIconType.link),
                  onPressed: _busy || _testing != null ? null : _test,
                ),
                SizedBox(
                  height: 18,
                  child: VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                RoundAction(
                  label: '保存',
                  icon: Icons.check_rounded,
                  iconWidget: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SettingsIcon(type: SettingsIconType.check),
                  onPressed: _busy ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SettingsPageBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: settingsPagePadding(
                context,
                const EdgeInsets.fromLTRB(16, 20, 16, 40),
              ),
              children: [
                _field('连接名称', _name, hint: '例如：随机菜单'),
                _field('服务地址', _url, hint: 'http://127.0.0.1:52147/mcp'),
                _field('访问令牌', _token, hint: '粘贴访问令牌', secret: true),
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    minTileHeight: 60,
                    title: const Text('启用连接', style: TextStyle(fontSize: 15)),
                    value: _enabled,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _enabled = value),
                  ),
                ),
                if (widget.connection != null) ...[
                  const SizedBox(height: 32),
                  DialogActionButton(
                    text: '删除连接',
                    role: DialogActionRole.destructive,
                    onPressed: _busy ? null : _delete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
