import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/library_asset.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';

Future<String?> showAssetRename(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AssetRenameDialog(name: name),
    );

class _AssetRenameDialog extends StatefulWidget {
  const _AssetRenameDialog({required this.name});
  final String name;
  @override
  State<_AssetRenameDialog> createState() => _AssetRenameDialogState();
}

class _AssetRenameDialogState extends State<_AssetRenameDialog> {
  late final _text = TextEditingController(text: widget.name);
  late final int _dot = widget.name.lastIndexOf('.');
  late final String _suffix = _dot > 0 ? widget.name.substring(_dot) : '';
  @override
  void initState() {
    super.initState();
    _text.text = _dot > 0 ? widget.name.substring(0, _dot) : widget.name;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, '${_text.text.trim()}$_suffix');
  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '重命名资产',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[/\\\x00-\x1f]')),
            ],
            autofocus: true,
            maxLength: 120 - _suffix.length,
            decoration: InputDecoration(
              hintText: '资产名称',
              suffixText: _suffix,
              fillColor: dialogControlColor(context),
              filled: true,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_text.text.trim().isNotEmpty) _save();
            },
          ),
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
              const SizedBox(width: 10),
              Expanded(
                child: DialogActionButton(
                  text: '保存',
                  onPressed: _text.text.trim().isEmpty ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<AssetSort?> showAssetSort(BuildContext context, AssetSort selected) =>
    showDialog<AssetSort>(
      context: context,
      builder: (context) => AppDialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '排序',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              RadioGroup<AssetSort>(
                groupValue: selected,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  children: [
                    for (final sort in AssetSort.values)
                      RadioListTile<AssetSort>(
                        title: Text(sort.label),
                        value: sort,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DialogActionButton(
                text: '取消',
                role: DialogActionRole.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
