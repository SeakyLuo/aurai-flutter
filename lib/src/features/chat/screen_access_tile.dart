import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'capability_icon.dart';

class ScreenAccessTile extends StatefulWidget {
  const ScreenAccessTile({
    super.key,
    required this.controller,
    required this.senderId,
  });
  final ChatController controller;
  final String senderId;

  @override
  State<ScreenAccessTile> createState() => _ScreenAccessTileState();
}

class _ScreenAccessTileState extends State<ScreenAccessTile> {
  late final _access = _load();

  Future<bool?> _load() async {
    try {
      return await widget.controller.getScreenAccess(widget.senderId);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('无法读取屏幕操作授权，请重新启动 App 后再试：${errorMessage(error)}'),
          ),
        );
      }
      return null;
    }
  }

  bool? _allowed;
  bool _saving = false;

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.controller.setScreenAccess(widget.senderId, value);
      if (mounted) setState(() => _allowed = value);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法保存屏幕操作授权，请重试：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool?>(
    future: _access,
    builder: (context, snapshot) => Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: const SizedBox.square(
          dimension: 32,
          child: Center(child: CapabilityIcon(id: 'screenAccess')),
        ),
        title: const Text(
          '屏幕操作',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '授权后持续有效',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: _saving || !snapshot.hasData
            ? null
            : () => _change(!(_allowed ?? snapshot.data!)),
        trailing: SizedBox(
          width: 60,
          height: 48,
          child: snapshot.hasData
              ? Switch(
                  value: _allowed ?? snapshot.data!,
                  onChanged: _saving ? null : _change,
                )
              : null,
        ),
      ),
    ),
  );
}
