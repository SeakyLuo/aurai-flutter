import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'capability_icon.dart';

class ScreenAccessTile extends StatefulWidget {
  const ScreenAccessTile({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ScreenAccessTile> createState() => _ScreenAccessTileState();
}

class _ScreenAccessTileState extends State<ScreenAccessTile> {
  late final _access = _load();

  Future<bool?> _load() async {
    try {
      return await widget.controller.getScreenAccess();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取屏幕操作授权，请重新启动 App 后再试')),
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
      await widget.controller.setScreenAccess(value);
      if (mounted) setState(() => _allowed = value);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法保存屏幕操作授权，请重试')));
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
      child: SwitchListTile(
        activeTrackColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff34d399)
            : const Color(0xff009b68),
        activeThumbColor: Theme.of(context).colorScheme.surface,
        inactiveTrackColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        inactiveThumbColor: Theme.of(context).colorScheme.onSurfaceVariant,
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        overlayColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        secondary: const SizedBox.square(
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
        value: _allowed ?? snapshot.data ?? false,
        onChanged: _saving || snapshot.connectionState != ConnectionState.done
            ? null
            : _change,
      ),
    ),
  );
}
