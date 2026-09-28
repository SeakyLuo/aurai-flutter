import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import 'app_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

const gitServiceHosts = <String, String>{
  'codeup.aliyun.com': 'Codeup',
  'github.com': 'GitHub',
  'gitlab.com': 'GitLab',
  'gitee.com': 'Gitee',
  'bitbucket.org': 'Bitbucket',
};

String gitServiceName(String host) => gitServiceHosts[host] ?? host;

class GitHttpsCredential {
  const GitHttpsCredential({
    required this.host,
    required this.username,
    required this.tokenConfigured,
    this.token,
  });

  factory GitHttpsCredential.fromPlatform(Map<Object?, Object?> value) =>
      GitHttpsCredential(
        host: value['host'] as String,
        username: value['username'] as String,
        tokenConfigured: value['tokenConfigured'] as bool,
      );

  final String host;
  final String username;
  final bool tokenConfigured;
  final String? token;

  Map<String, Object?> toPlatform() => {
    'host': host,
    'username': username,
    'token': token,
  };
}

class GitCredentialEditorResult {
  const GitCredentialEditorResult.saved(this.credential) : deleted = false;
  const GitCredentialEditorResult.deleted() : credential = null, deleted = true;

  final GitHttpsCredential? credential;
  final bool deleted;
}

class GitCredentialEditorPage extends StatefulWidget {
  const GitCredentialEditorPage({
    super.key,
    required this.credential,
    required this.existingHosts,
    this.initialHost,
  });

  final GitHttpsCredential? credential;
  final Set<String> existingHosts;
  final String? initialHost;

  @override
  State<GitCredentialEditorPage> createState() =>
      _GitCredentialEditorPageState();
}

class _GitCredentialEditorPageState extends State<GitCredentialEditorPage> {
  late final TextEditingController _host;
  late final TextEditingController _username;
  final _token = TextEditingController();
  bool _obscureToken = true;

  bool get _editing => widget.credential != null;
  bool get _customHost => !_editing && widget.initialHost == null;
  bool get _github => _host.text == 'github.com';
  bool get _codeup => _host.text == 'codeup.aliyun.com';
  bool get _automaticUsername => _github;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(
      text: widget.credential?.host ?? widget.initialHost,
    );
    _username = TextEditingController(
      text:
          widget.credential?.username ??
          (widget.initialHost == 'github.com' ? 'git' : null),
    );
  }

  @override
  void dispose() {
    _host.dispose();
    _username.dispose();
    _token.dispose();
    super.dispose();
  }

  void _save() {
    final host = _host.text.trim().toLowerCase();
    final username = _github ? 'git' : _username.text.trim();
    final token = _token.text.trim();
    if (host.isEmpty || !host.contains('.')) {
      _notice('请输入 Git 服务域名');
      return;
    }
    if (widget.existingHosts.contains(host)) {
      _notice('这个 Git 服务已经配置');
      return;
    }
    if (!_automaticUsername && username.isEmpty) {
      _notice('请输入 HTTPS 用户名');
      return;
    }
    if (!_editing && token.isEmpty) {
      _notice('请输入 HTTPS 密码或访问令牌');
      return;
    }
    Navigator.pop(
      context,
      GitCredentialEditorResult.saved(
        GitHttpsCredential(
          host: host,
          username: username,
          tokenConfigured:
              token.isNotEmpty || widget.credential!.tokenConfigured,
          token: token.isEmpty ? null : token,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '删除 HTTPS 凭据？',
        description: '之后使用 ${widget.credential!.host} 拉取或推送时，需要重新配置。',
        confirmLabel: '删除',
        confirmRole: DialogActionRole.destructive,
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const GitCredentialEditorResult.deleted());
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: _editing
          ? gitServiceName(widget.credential!.host)
          : widget.initialHost == null
          ? '其他 Git 服务'
          : gitServiceName(widget.initialHost!),
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '保存',
          icon: Icons.check_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.check),
          onPressed: _save,
        ),
      ],
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: settingsPagePadding(
                context,
                const EdgeInsets.fromLTRB(16, 12, 16, 32),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_customHost) ...[
                  _field('服务地址', _host, '例如 git.example.com'),
                  const SizedBox(height: 16),
                ],
                if (!_automaticUsername) ...[
                  _field('HTTPS 用户名', _username, '代码托管账号'),
                  const SizedBox(height: 16),
                ],
                _field(
                  _codeup ? '个人访问令牌' : 'HTTPS 密码或访问令牌',
                  _token,
                  widget.credential?.tokenConfigured == true
                      ? '已配置，留空保持不变'
                      : _codeup
                      ? '输入 Codeup 个人访问令牌'
                      : '输入密码或 Personal Access Token',
                  obscureText: _obscureToken,
                  sensitive: true,
                  suffix: IconButton(
                    tooltip: _obscureToken ? '显示令牌' : '隐藏令牌',
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                    icon: SettingsIcon(
                      type: _obscureToken
                          ? SettingsIconType.eye
                          : SettingsIconType.eyeOff,
                    ),
                  ),
                ),
                if (_editing) ...[
                  const SizedBox(height: 28),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      minVerticalPadding: 16,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      leading: SettingsIcon(
                        type: SettingsIconType.reset,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        '删除凭据',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: _delete,
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

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool enabled = true,
    bool obscureText = false,
    bool sensitive = false,
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
        enabled: enabled,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: !sensitive,
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
