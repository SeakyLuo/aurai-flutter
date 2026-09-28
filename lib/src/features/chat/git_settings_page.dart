import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../platform/aurai_platform.dart';
import 'choice_sheet.dart';
import 'git_credential_editor_page.dart';
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
  List<GitHttpsCredential> _credentials = [];
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
      setState(() {
        _credentials = (config['httpsCredentials'] as List<Object?>)
            .cast<Map<Object?, Object?>>()
            .map(GitHttpsCredential.fromPlatform)
            .toList();
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      _notice('Git 设置读取失败：${errorMessage(error)}');
      setState(() => _loading = false);
    }
  }

  Future<void> _save({bool close = true}) async {
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
            'httpsCredentials': _credentials
                .map((credential) => credential.toPlatform())
                .toList(),
          },
        },
      );
      if (!mounted) return;
      setState(() {
        _credentials = (config['httpsCredentials'] as List<Object?>)
            .cast<Map<Object?, Object?>>()
            .map(GitHttpsCredential.fromPlatform)
            .toList();
      });
      if (close) Navigator.pop(context);
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
              ? () => _save()
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
                      _field('提交署名', _name, '用于 Git 提交记录'),
                      const SizedBox(height: 16),
                      _field(
                        '提交邮箱',
                        _email,
                        'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      _field('默认分支', _branch, 'main'),
                      const SizedBox(height: 28),
                      _credentialsHeader(),
                      const SizedBox(height: 12),
                      for (
                        var index = 0;
                        index < _credentials.length;
                        index++
                      ) ...[_credentialTile(index), const SizedBox(height: 12)],
                      _addCredentialTile(),
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
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: settingsFieldColor(context),
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

  Widget _credentialsHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Text(
      '代码托管账号',
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _credentialTile(int index) {
    final credential = _credentials[index];
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 16,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: const SettingsIcon(type: SettingsIconType.git),
        title: Text(gitServiceName(credential.host)),
        subtitle: Text(
          credential.tokenConfigured
              ? gitServiceHosts.containsKey(credential.host)
                    ? '已配置'
                    : credential.username
              : '未配置密码或令牌',
        ),
        trailing: const SettingsIcon(type: SettingsIconType.chevron),
        onTap: _saving ? null : () => _editCredential(index),
      ),
    );
  }

  Widget _addCredentialTile() => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minVerticalPadding: 16,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: const SettingsIcon(type: SettingsIconType.add),
      title: const Text('添加代码托管账号'),
      subtitle: const Text('Codeup、GitHub 等'),
      onTap: _saving ? null : _addCredential,
    ),
  );

  Future<void> _addCredential() async {
    final host = await showChoiceSheet<String>(
      context,
      title: '代码托管服务',
      selected: '',
      choices: [
        for (final entry in gitServiceHosts.entries)
          if (!_credentials.any((credential) => credential.host == entry.key))
            (value: entry.key, label: entry.value),
        (value: 'custom', label: '其他 Git 服务'),
      ],
    );
    if (!mounted || host == null) return;
    await _editCredential(null, initialHost: host == 'custom' ? null : host);
  }

  Future<void> _editCredential(int? index, {String? initialHost}) async {
    final result = await Navigator.push<GitCredentialEditorResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GitCredentialEditorPage(
          credential: index == null ? null : _credentials[index],
          initialHost: initialHost,
          existingHosts: {
            for (
              var itemIndex = 0;
              itemIndex < _credentials.length;
              itemIndex++
            )
              if (itemIndex != index) _credentials[itemIndex].host,
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.deleted) {
        _credentials.removeAt(index!);
      } else if (index == null) {
        _credentials.add(result.credential!);
      } else {
        _credentials[index] = result.credential!;
      }
    });
    await _save(close: false);
  }
}
