import 'package:flutter/material.dart';

import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';

class FriendNotificationSwitch extends StatelessWidget {
  const FriendNotificationSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      minTileHeight: 60,
      title: const Text('通知成为好友', style: TextStyle(fontSize: 15)),
      value: value,
      onChanged: onChanged,
    ),
  );
}

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key, required this.name});
  final String name;

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  bool _notifyFriend = true;

  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '添加朋友',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(widget.name, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FriendNotificationSwitch(
            value: _notifyFriend,
            onChanged: (value) => setState(() => _notifyFriend = value),
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
                  text: '添加',
                  onPressed: () => Navigator.pop(context, _notifyFriend),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
