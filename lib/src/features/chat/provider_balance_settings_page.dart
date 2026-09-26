import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProviderBalanceSettingsPage extends StatefulWidget {
  const ProviderBalanceSettingsPage({
    super.key,
    required this.controller,
    required this.service,
  });

  final ChatController controller;
  final ModelService service;

  @override
  State<ProviderBalanceSettingsPage> createState() =>
      _ProviderBalanceSettingsPageState();
}

class _ProviderBalanceSettingsPageState
    extends State<ProviderBalanceSettingsPage> {
  late final ProviderBalanceConfig? _initial = widget.controller.modelSettings
      .profile(widget.service)
      .balanceConfig;
  late final Map<String, TextEditingController> _fields = {
    'url': TextEditingController(text: _initial?.url ?? ''),
    'itemsPath': TextEditingController(text: _initial?.itemsPath ?? ''),
    'availablePath': TextEditingController(text: _initial?.availablePath ?? ''),
    'successPath': TextEditingController(text: _initial?.successPath ?? ''),
    'successValue': TextEditingController(
      text: _initial?.successValue ?? 'true',
    ),
    'currencyPath': TextEditingController(text: _initial?.currencyPath ?? ''),
    'currency': TextEditingController(text: _initial?.currency ?? ''),
    'totalPath': TextEditingController(text: _initial?.totalPath ?? ''),
    'toppedUpPath': TextEditingController(text: _initial?.toppedUpPath ?? ''),
    'grantedPath': TextEditingController(text: _initial?.grantedPath ?? ''),
    'grantedLabel': TextEditingController(text: _initial?.grantedLabel ?? '赠金'),
    'topUpUrl': TextEditingController(text: _initial?.topUpUrl ?? ''),
  };
  bool _saving = false;
  bool _allowPop = false;

  String _value(String name) => _fields[name]!.text.trim();

  bool get _dirty =>
      _value('url') != (_initial?.url ?? '') ||
      _value('itemsPath') != (_initial?.itemsPath ?? '') ||
      _value('availablePath') != (_initial?.availablePath ?? '') ||
      _value('successPath') != (_initial?.successPath ?? '') ||
      _value('successValue') != (_initial?.successValue ?? 'true') ||
      _value('currencyPath') != (_initial?.currencyPath ?? '') ||
      _value('currency') != (_initial?.currency ?? '') ||
      _value('totalPath') != (_initial?.totalPath ?? '') ||
      _value('toppedUpPath') != (_initial?.toppedUpPath ?? '') ||
      _value('grantedPath') != (_initial?.grantedPath ?? '') ||
      _value('grantedLabel') != (_initial?.grantedLabel ?? '赠金') ||
      _value('topUpUrl') != (_initial?.topUpUrl ?? '');

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_value('url').isEmpty) {
      _notice('请填写余额查询地址');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveProviderBalanceConfig(
        widget.service,
        ProviderBalanceConfig(
          url: _value('url'),
          itemsPath: _value('itemsPath'),
          availablePath: _value('availablePath'),
          successPath: _value('successPath'),
          successValue: _value('successValue'),
          currencyPath: _value('currencyPath'),
          currency: _value('currency'),
          totalPath: _value('totalPath'),
          toppedUpPath: _value('toppedUpPath'),
          grantedPath: _value('grantedPath'),
          grantedLabel: _value('grantedLabel'),
          topUpUrl: _value('topUpUrl'),
        ),
      );
      if (!mounted) return;
      _notice('账户余额设置已保存');
      setState(() => _allowPop = true);
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.saveProviderBalanceConfig(widget.service, null);
      if (!mounted) return;
      _notice('账户余额设置已恢复');
      setState(() => _allowPop = true);
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (!_dirty) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '账户余额设置还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save();
    } else if (action == 'discard') {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Widget _field(String name, String label, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: _fields[name],
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          keyboardType: name.endsWith('Url') || name == 'url'
              ? TextInputType.url
              : TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
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
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '账户余额设置',
        onBack: _leave,
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving || !_dirty ? null : _save,
          ),
        ],
      ),
      body: SettingsPageBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: settingsPagePadding(
                context,
                const EdgeInsets.fromLTRB(16, 20, 16, 32),
              ),
              children: [
                _field('url', '余额查询地址', 'https://example.com/user/balance'),
                _field('topUpUrl', '充值页面地址', '选填，使用供应商控制台地址'),
                const SizedBox(height: 8),
                _field('itemsPath', '余额列表字段', '单条余额留空，例如 balance_infos'),
                _field('totalPath', '可用余额字段', '例如 data.available_balance'),
                _field('toppedUpPath', '充值余额字段', '例如 data.cash_balance'),
                _field('grantedPath', '赠送余额字段', '例如 data.voucher_balance'),
                _field('currencyPath', '币种字段', '固定币种时留空，例如 currency'),
                _field('currency', '固定币种', '例如 CNY；使用币种字段时留空'),
                _field('availablePath', '可调用状态字段', '选填，例如 is_available'),
                _field('successPath', '请求成功字段', '选填，例如 status'),
                _field('successValue', '请求成功值', '例如 true 或 0'),
                _field('grantedLabel', '赠送余额名称', '例如 赠金或代金券'),
                if (widget.controller.modelSettings
                        .profile(widget.service)
                        .details
                        ?.balance !=
                    null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving ? null : _reset,
                      child: Text(
                        widget.service.defaultBalance == null
                            ? '移除余额查询配置'
                            : '恢复供应商预设',
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
