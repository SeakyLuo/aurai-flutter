import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_controller.dart';

Future<void> showAccessibilityRequestSheet(
  BuildContext context,
  ChatController controller,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AccessibilityRequestSheet(controller: controller),
  );
  if (controller.accessibilityRequestPending) {
    controller.cancelAccessibilityRequest();
    messenger.showSnackBar(const SnackBar(content: Text('本次暂不开启无障碍')));
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
        messenger.showSnackBar(const SnackBar(content: Text('等待超时，已自动拒绝本次请求')));
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
    } on Object {
      if (mounted) {
        _messenger.showSnackBar(const SnackBar(content: Text('无法打开无障碍设置，请重试')));
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '开启无障碍权限',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Aurai 需要无障碍权限来查看和操作其他 App。开启后返回，任务会自动继续。',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_wentToSettings ? '等待开启无障碍，' : ''}${seconds} 秒后自动拒绝',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('暂不开启'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _opening ? null : _enable,
                    child: const Text('去开启'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
