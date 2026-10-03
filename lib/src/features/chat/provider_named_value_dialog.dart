import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import '../../app/glass_notice.dart';

Future<({String id, String name})?> editProviderNamedValue(
  BuildContext context, {
  required String title,
  required String valueLabel,
  ({String id, String name})? initial,
  Set<String> existingValues = const {},
  bool editValue = true,
}) => showDialog<({String id, String name})>(
  context: context,
  builder: (_) => _NamedValueDialog(
    title: title,
    valueLabel: valueLabel,
    initial: initial,
    existingValues: existingValues,
    editValue: editValue,
  ),
);

class _NamedValueDialog extends StatefulWidget {
  const _NamedValueDialog({
    required this.title,
    required this.valueLabel,
    this.initial,
    required this.existingValues,
    required this.editValue,
  });
  final String title, valueLabel;
  final ({String id, String name})? initial;
  final Set<String> existingValues;
  final bool editValue;
  @override
  State<_NamedValueDialog> createState() => _NamedValueDialogState();
}

class _NamedValueDialogState extends State<_NamedValueDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _value = TextEditingController(text: widget.initial?.id ?? '');
  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.existingValues.contains(_value.text.trim())) {
      ScaffoldMessenger.of(
        context,
      ).showToast(const SnackBar(content: Text('这个名称已经添加')));
      return;
    }
    Navigator.pop(context, (id: _value.text.trim(), name: _name.text.trim()));
  }

  InputDecoration _decoration(String label) => InputDecoration(
    hintText: label,
    counterText: '',
    filled: true,
    fillColor: settingsFieldColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: 60,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('显示名称'),
          ),
          if (widget.editValue) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              maxLength: 200,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(widget.valueLabel),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DialogActionButton(
                  text: '取消',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DialogActionButton(
                  text: '保存',
                  role: DialogActionRole.primary,
                  onPressed:
                      _name.text.trim().isEmpty || _value.text.trim().isEmpty
                      ? null
                      : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
