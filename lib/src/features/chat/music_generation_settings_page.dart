import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/music_generation_config.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class MusicGenerationSettingsPage extends StatefulWidget {
  const MusicGenerationSettingsPage({super.key, required this.controller});

  final ChatController controller;

  @override
  State<MusicGenerationSettingsPage> createState() =>
      _MusicGenerationSettingsPageState();
}

class _MusicGenerationSettingsPageState
    extends State<MusicGenerationSettingsPage> {
  final _key = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_key.text.trim().isEmpty) {
      _leave();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '音乐生成密钥还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') await _save();
    if (action == 'discard') _leave();
  }

  Future<void> _save() async {
    final value = _key.text.trim();
    if (value.isEmpty) {
      _notice('请输入 API 密钥');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveMusicGeneration(
        MusicGenerationConfig(apiKey: value),
      );
      if (!mounted) return;
      _notice('音乐生成密钥已保存');
      _key.clear();
      _leave();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '音乐生成',
        onBack: _saving ? null : _back,
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving || _key.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(24),
                  child: const ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: Text('服务商'),
                    subtitle: Text(MusicGenerationConfig.serviceName),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: TextField(
                      controller: _key,
                      enabled: !_saving,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'API 密钥',
                        hintText:
                            widget
                                    .controller
                                    .musicGeneration
                                    ?.apiKey
                                    .isNotEmpty ==
                                true
                            ? '已配置，输入新密钥可替换'
                            : '输入此平台的 API 密钥',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? '显示密钥' : '隐藏密钥',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: SettingsIcon(
                            type: _obscure
                                ? SettingsIconType.eye
                                : SettingsIconType.eyeOff,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '需要在 open.suno.cn 单独获取密钥，按该平台规则计费。每次生成两个音乐版本，完成后保存在会话中，点击音频文件可用设备播放器打开。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
