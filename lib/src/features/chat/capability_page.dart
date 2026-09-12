import 'package:flutter/material.dart';

import '../../domain/capability.dart';
import 'chat_controller.dart';

class CapabilityPage extends StatefulWidget {
  const CapabilityPage({super.key, required this.controller});

  final ChatController controller;

  static Future<void> show(
    BuildContext context,
    ChatController controller,
  ) async {
    try {
      await controller.refreshCapabilities();
    } on Object {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取设备能力，请稍后再试')));
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
      appBar: AppBar(
        title: const Text('设备能力'),
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 24),
              children: [
                for (final capability in widget.controller.capabilities)
                  if (!capability.id.startsWith('android.execution.'))
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _icon(capability.availability),
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capability.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _description(capability),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _action(capability),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  Widget _action(Capability capability) {
    if (capability.availability == CapabilityAvailability.permissionRequired) {
      final action = switch (capability.id) {
        'android.accessibility' ||
        'android.vision' => widget.controller.openAccessibilitySettings,
        'android.notifications.observe' =>
          widget.controller.openNotificationAccessSettings,
        _ => null,
      };
      if (action != null)
        return TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            minimumSize: const Size(48, 48),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            overlayColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => _perform(action),
          child: const Text('去开启'),
        );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        _label(capability.availability),
        style: TextStyle(
          fontSize: 12,
          color: capability.isAvailable
              ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xff90c4ad)
                    : const Color(0xff588575))
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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

  static IconData _icon(CapabilityAvailability availability) =>
      switch (availability) {
        CapabilityAvailability.available => Icons.check_circle_outline_rounded,
        CapabilityAvailability.permissionRequired => Icons.lock_outline_rounded,
        CapabilityAvailability.unavailable => Icons.error_outline_rounded,
        CapabilityAvailability.unsupported => Icons.block_rounded,
      };

  static String _label(CapabilityAvailability availability) =>
      switch (availability) {
        CapabilityAvailability.available => '可用',
        CapabilityAvailability.permissionRequired => '需要授权',
        CapabilityAvailability.unavailable => '不可用',
        CapabilityAvailability.unsupported => '不支持',
      };
}
