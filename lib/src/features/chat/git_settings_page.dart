import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../platform/aurai_platform.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GitSettingsPage extends StatefulWidget {
  const GitSettingsPage({super.key});

  @override
  State<GitSettingsPage> createState() => _GitSettingsPageState();
}

class _GitSettingsPageState extends State<GitSettingsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _branch = TextEditingController();
  final _httpsUsername = TextEditingController();
  final _httpsToken = TextEditingController();
  bool _tokenConfigured = false;
  bool _clearToken = false;
  bool _obscureToken = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _branch.dispose();
    _httpsUsername.dispose();
    _httpsToken.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await AuraiPlatform.instance.deviceExtension(
        'getGitConfiguration',
      );
      if (!mounted) return;
      _name.text = config['name'] as String;
      _email.text = config['email'] as String;
      _branch.text = config['defaultBranch'] as String;
      _httpsUsername.text = config['httpsUsername'] as String;
      setState(() {
        _tokenConfigured = config['httpsTokenConfigured'] as bool;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      _notice('Git 设置读取失败：${errorMessage(error)}');
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _branch.text.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final config = await AuraiPlatform.instance.deviceExtension(
        'setGitConfiguration',
        {
          'configuration': {
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'defaultBranch': _branch.text.trim(),
            'httpsUsername': _httpsUsername.text.trim(),
            'httpsToken': _httpsToken.text.trim().isEmpty
                ? null
                : _httpsToken.text.trim(),
            'clearHttpsToken': _clearToken,
          },
        },
      );
      if (!mounted) return;
      _httpsToken.clear();
      setState(() {
        _tokenConfigured = config['httpsTokenConfigured'] as bool;
        _clearToken = false;
      });
      _notice('Git 设置已保存');
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: 'Git',
      onBack: _saving ? null : () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: _saving ? '正在保存' : '保存',
          icon: Icons.check_rounded,
          iconWidget: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const SettingsIcon(type: SettingsIconType.check),
          onPressed: !_loading && !_saving && _branch.text.trim().isNotEmpty
              ? _save
              : null,
        ),
      ],
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _loading
                ? const SizedBox.shrink()
                : ListView(
                    padding: settingsPagePadding(
                      context,
                      const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _field('提交用户名', _name, '用于 Git 提交记录'),
                      const SizedBox(height: 16),
                      _field(
                        '提交邮箱',
                        _email,
                        'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      _field('默认分支', _branch, 'main'),
                      const SizedBox(height: 24),
                      _field('HTTPS 用户名', _httpsUsername, 'Git 服务账号'),
                      const SizedBox(height: 16),
                      _field(
                        'HTTPS 访问令牌',
                        _httpsToken,
                        _clearToken
                            ? '保存后清除现有令牌'
                            : _tokenConfigured
                            ? '已配置，留空保持不变'
                            : '输入 Personal Access Token',
                        obscureText: _obscureToken,
                        suffix: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _obscureToken ? '显示令牌' : '隐藏令牌',
                              onPressed: () => setState(
                                () => _obscureToken = !_obscureToken,
                              ),
                              icon: SettingsIcon(
                                type: _obscureToken
                                    ? SettingsIconType.eye
                                    : SettingsIconType.eyeOff,
                              ),
                            ),
                            if (_tokenConfigured)
                              IconButton(
                                tooltip: _clearToken ? '保留现有令牌' : '清除令牌',
                                onPressed: () =>
                                    setState(() => _clearToken = !_clearToken),
                                icon: SettingsIcon(
                                  type: SettingsIconType.reset,
                                  color: _clearToken
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: settingsFieldColor(context),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}
