import 'package:flutter/material.dart';

import '../../domain/contact_display_names.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';

class ContactRemarkDialog extends StatefulWidget {
  const ContactRemarkDialog({super.key, required this.senderId});
  final String senderId;

  @override
  State<ContactRemarkDialog> createState() => _ContactRemarkDialogState();
}

class _ContactRemarkDialogState extends State<ContactRemarkDialog> {
  late final _text = TextEditingController(
    text: ContactDisplayNames.remark(widget.senderId) ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '设置备注名',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '留空恢复原名',
              filled: true,
              fillColor: dialogControlColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
            ),
            onSubmitted: (_) => Navigator.pop(context, _text.text.trim()),
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
                  onPressed: () => Navigator.pop(context, _text.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
