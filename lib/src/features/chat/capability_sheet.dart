import 'package:flutter/material.dart';

import '../../domain/capability.dart';
import 'chat_controller.dart';
import 'model_settings_sheet.dart';

class CapabilitySheet extends StatefulWidget {
  const CapabilitySheet({super.key, required this.controller});

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
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => CapabilitySheet(controller: controller),
    );
  }

  @override
  State<CapabilitySheet> createState() => _CapabilitySheetState();
}

class _CapabilitySheetState extends State<CapabilitySheet>
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
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.78,
    child: ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '设备能力',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '按需授权，由你掌控',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              const Text(
                '需要额外权限时，Aurai 会在任务中征求你的同意。',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xff737580),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
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
                                      color: const Color(0xffedf5ff),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _icon(capability.availability),
                                      size: 20,
                                      color: const Color(0xff1685f8),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
            ],
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
    if (capability.id == 'android.vision' &&
        !widget.controller.config.supportsImageInput) {
      return TextButton(
        onPressed: () {
          if (widget.controller.isBusy) {
            _messenger.currentState!.showSnackBar(
              const SnackBar(content: Text('请先停止当前任务，再修改模型')),
            );
            return;
          }
          ModelSettingsSheet.show(
            context,
            controller: widget.controller,
            continueAfterSave: false,
          );
        },
        child: const Text('配置'),
      );
    }
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
          onPressed: () => _perform(action),
          child: const Text('去开启'),
        );
    }
    return Text(
      _label(capability.availability),
      style: TextStyle(
        fontSize: 12,
        color: capability.isAvailable
            ? const Color(0xff588575)
            : const Color(0xff92929c),
      ),
    );
  }

  String _description(Capability capability) => switch (capability.id) {
    'android.network' => '查看网络状态，检查连接是否正常',
    'android.observe' => '了解手机与当前页面的状态',
    'android.intents' => '在确认后打开应用内的操作',
    'android.shell.app_uid' => '仅使用 Aurai 自身权限执行命令',
    'android.vision' when !widget.controller.config.supportsImageInput =>
      '在模型配置中开启屏幕分析',
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
