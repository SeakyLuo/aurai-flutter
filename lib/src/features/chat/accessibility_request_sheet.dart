import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'authorization_sheet_content.dart';

Future<void> showAccessibilityRequestSheet(
  BuildContext context,
  ChatController controller,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _AccessibilityRequestSheet(controller: controller),
  );
  if (controller.accessibilityRequestPending) {
    controller.cancelAccessibilityRequest();
    messenger.showGlassSnackBar(const SnackBar(content: Text('本次暂不开启无障碍')));
  }
}

class _AccessibilityRequestSheet extends StatefulWidget {
  const _AccessibilityRequestSheet({required this.controller});
  final ChatController controller;

  @override
  State<_AccessibilityRequestSheet> createState() =>
      _AccessibilityRequestSheetState();
}

class _AccessibilityRequestSheetState
    extends State<_AccessibilityRequestSheet> {
  Timer? _ticker;
  bool _closing = false;
  bool _opening = false;
  bool _wentToSettings = false;
  late final _messenger = ScaffoldMessenger.of(context);
  late DateTime _deadline;

  @override
  void initState() {
    super.initState();
    _deadline = widget.controller.accessibilityDeadline!;
    widget.controller.addListener(_changed);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_closing) return;
    if (widget.controller.accessibilityRequestPending) {
      setState(() => _deadline = widget.controller.accessibilityDeadline!);
      return;
    }
    _closing = true;
    final timedOut = !DateTime.now().isBefore(_deadline);
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = _messenger;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
      if (timedOut) {
        messenger.showGlassSnackBar(const SnackBar(content: Text('等待超时，已自动拒绝本次请求')));
      }
    });
  }

  Future<void> _enable() async {
    setState(() {
      _opening = true;
      _wentToSettings = true;
    });
    try {
      await widget.controller.enableRequestedAccessibility();
    } on Object catch (error) {
      if (mounted) {
        _messenger.showGlassSnackBar(
          SnackBar(content: Text('无法打开无障碍设置，请重试：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds =
        ((_deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil())
            .clamp(0, 120);
    return AuthorizationSheetContent(
      title: '开启无障碍权限',
      content: Text(
        _wentToSettings
            ? '等待开启无障碍。开启后返回 Aurai，任务会自动继续。'
            : 'Aurai 需要无障碍权限来查看和操作其他 App。开启后返回，任务会自动继续。',
      ),
      allowLabel: _opening ? '正在打开…' : '去开启',
      onAllow: _opening ? null : _enable,
      onDeny: () => Navigator.pop(context),
      seconds: seconds,
    );
  }
}
