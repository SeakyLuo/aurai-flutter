import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

import '../../domain/capability.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'capability_icon.dart';
import 'device_extension_tiles.dart';
import 'document_folders_page.dart';

class CapabilityPage extends StatefulWidget {
  const CapabilityPage({super.key, required this.controller});

  final ChatController controller;

  static Future<void> show(
    BuildContext context,
    ChatController controller,
  ) async {
    try {
      await controller.refreshCapabilities();
    } on Object catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法读取设备能力，请稍后再试：${errorMessage(error)}')),
        );
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CapabilityPage(controller: controller)),
    );
  }

  @override
  State<CapabilityPage> createState() => _CapabilityPageState();
}

class _CapabilityPageState extends State<CapabilityPage>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _perform(widget.controller.refreshCapabilities);
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    key: _messenger,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        gradientBackground: true,
        title: '设备能力',
        onBack: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 76 + 16,
                16,
                24,
              ),
              children: [
                const SizedBox(height: 8),
                for (final capability in widget.controller.capabilities)
                  if (!capability.id.startsWith('android.execution.') &&
                      capability.id != 'android.network.capture')
                    _capabilityTile(capability),
                const DeviceExtensionTiles(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted)
        _messenger.currentState!.showSnackBar(
          const SnackBar(content: Text('操作未完成，请稍后重试')),
        );
    }
  }

  Future<void> Function()? _permissionAction(Capability capability) {
    if (capability.id == 'android.documents')
      return () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const DocumentFoldersPage()),
        );
      };
    if (capability.availability != CapabilityAvailability.permissionRequired) {
      return null;
    }
    return switch (capability.id) {
      'android.accessibility' ||
      'android.vision' => widget.controller.openAccessibilitySettings,
      'android.notifications.observe' =>
        widget.controller.openNotificationAccessSettings,
      _ => null,
    };
  }

  Widget _capabilityTile(Capability capability) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final action = _permissionAction(capability);
    final statusColor = capability.isAvailable
        ? (dark ? const Color(0xff34d399) : const Color(0xff009b68))
        : colors.onSurfaceVariant;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: Center(child: CapabilityIcon(id: capability.id)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capability.name,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _description(capability),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: capability.isAvailable
                  ? (dark ? const Color(0xff193b31) : const Color(0xffe8f4f3))
                  : dark && action != null
                  ? const Color(0xff38383d)
                  : statusColor.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              capability.id == 'android.documents'
                  ? '管理'
                  : action == null
                  ? _label(capability.availability)
                  : '去开启',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: capability.isAvailable
                    ? (dark ? const Color(0xff6ee7b7) : const Color(0xff008577))
                    : dark && action != null
                    ? Colors.white
                    : statusColor,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: action == null
            ? content
            : InkWell(onTap: () => _perform(action), child: content),
      ),
    );
  }

  String _description(Capability capability) => switch (capability.id) {
    'android.network' => '查看网络状态，检查连接是否正常',
    'android.observe' => '了解手机与当前页面的状态',
    'android.intents' => '在确认后打开应用内的操作',
    'android.shell.app_uid' => '仅使用 Aurai 自身权限执行命令',
    _ => capability.reason,
  };

  static String _label(CapabilityAvailability availability) =>
      switch (availability) {
        CapabilityAvailability.available => '可用',
        CapabilityAvailability.permissionRequired => '需要授权',
        CapabilityAvailability.unavailable => '不可用',
        CapabilityAvailability.unsupported => '不支持',
      };
}
