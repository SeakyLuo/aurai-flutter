import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/model_provider.dart';
import 'app_dialog.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'settings_icon.dart';

class ProviderKeyDialog extends StatefulWidget {
  const ProviderKeyDialog({
    super.key,
    required this.controller,
    required this.service,
    required this.baseUrl,
    required this.cancelled,
  });
  final ChatController controller;
  final ModelService service;
  final String baseUrl;
  final ValueNotifier<bool> cancelled;
  @override
  State<ProviderKeyDialog> createState() => _ProviderKeyDialogState();
}

class _ProviderKeyDialogState extends State<ProviderKeyDialog> {
  final _key = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  @override
  void initState() {
    super.initState();
    widget.cancelled.addListener(_cancel);
  }

  void _cancel() {
    if (widget.cancelled.value && mounted && !_saving)
      Navigator.pop(context, false);
  }

  @override
  void dispose() {
    widget.cancelled.removeListener(_cancel);
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_key.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('请输入 API 密钥')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveProviderKey(
        widget.service,
        widget.baseUrl,
        _key.text,
        widget.cancelled,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (widget.cancelled.value) {
        Navigator.pop(context, false);
        return;
      }
      ScaffoldMessenger.of(context).showGlassSnackBar(
        const SnackBar(content: Text('密钥保存失败，请确认供应商地址未变化后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '配置 ${widget.controller.modelSettings.profile(widget.service).displayName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              widget.baseUrl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _key,
              enabled: !_saving,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API 密钥',
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示密钥' : '隐藏密钥',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: SettingsIcon(
                    type: _obscure
                        ? SettingsIconType.eye
                        : SettingsIconType.eyeOff,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '密钥仅加密保存在本机，不会发送给 AI。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            DialogActionButton(
              text: '保存',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 8),
            DialogActionButton(
              text: '取消',
              role: DialogActionRole.secondary,
              onPressed: _saving ? null : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    ),
  );
}
