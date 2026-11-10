import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/glass_notice.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
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
  bool _busy = false, _leaving = false, _showToken = false;
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

  void _changed() => setState(() {});
  @override
  void dispose() {
    _testing?.close();
    for (final c in [_name, _url, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notice(String text, {ToastKind kind = ToastKind.error}) =>
      AppToasts.show(SnackBar(content: Text(text)), kind: kind);
  void _pop() {
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
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
    setState(() => _busy = true);
    final client = _testing = McpClient(_value);
    try {
      final result = await client.listTools();
      if (mounted)
        _notice(
          '连接成功，已发现 ${(result['tools'] as List).length} 个工具${result['nextCursor'] == null ? '' : '，还有更多'}',
          kind: ToastKind.success,
        );
    } on Object catch (error) {
      if (mounted) _notice(error.toString());
    } finally {
      client.close();
      _testing = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
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
    String? hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      autocorrect: !secret && label == '连接名称',
      enableSuggestions: !secret,
      obscureText: secret && !_showToken,
      keyboardType: label == '服务地址' ? TextInputType.url : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: secret
            ? IconButton(
                tooltip: _showToken ? '隐藏令牌' : '显示令牌',
                onPressed: () => setState(() => _showToken = !_showToken),
                icon: SettingsIcon(
                  type: _showToken
                      ? SettingsIconType.eyeOff
                      : SettingsIconType.eye,
                ),
              )
            : null,
      ),
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
          SettingsGlassAction(
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
      body: SettingsPageBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: settingsPagePadding(
                context,
                const EdgeInsets.fromLTRB(16, 16, 16, 40),
              ),
              children: [
                _field('连接名称', _name, hint: '随机菜单'),
                _field('服务地址', _url, hint: 'http://127.0.0.1:52147/mcp'),
                _field('访问令牌', _token, secret: true),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许 AI 使用'),
                  subtitle: const Text('保存后生效；开启不代表服务当前在线'),
                  value: _enabled,
                  onChanged: _busy ? null : (v) => setState(() => _enabled = v),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _busy ? null : _test,
                  child: const Text('测试连接'),
                ),
                const SizedBox(height: 16),
                const Text(
                  '使用 Streamable HTTP。随机菜单的地址和令牌可在其「我的 → MCP 连接」中复制。测试只检查当前填写的配置，不会保存。',
                ),
                if (widget.connection != null) ...[
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: Text(
                      '删除连接',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
