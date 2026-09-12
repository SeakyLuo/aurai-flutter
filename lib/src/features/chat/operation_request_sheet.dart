import 'dart:async';

import 'package:flutter/material.dart';

import 'authorization_sheet_content.dart';
import 'chat_controller.dart';

Future<bool> showOperationRequestSheet(
  BuildContext context, {
  required ChatController controller,
  required PendingConfirmation request,
  required String detail,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => _OperationRequestSheet(
        controller: controller,
        request: request,
        detail: detail,
      ),
    ) ??
    false;

class _OperationRequestSheet extends StatefulWidget {
  const _OperationRequestSheet({
    required this.controller,
    required this.request,
    required this.detail,
  });
  final ChatController controller;
  final PendingConfirmation request;
  final String detail;

  @override
  State<_OperationRequestSheet> createState() => _OperationRequestSheetState();
}

class _OperationRequestSheetState extends State<_OperationRequestSheet> {
  late final Timer _ticker;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    widget.request.completer.future.then((_) {
      if (mounted) _changed();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_closing ||
        identical(widget.controller.pendingConfirmation, widget.request))
      return;
    _closing = true;
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route.isCurrent) {
        navigator.pop(false);
      } else {
        navigator.removeRoute(route);
      }
    });
  }

  void _answer(bool approved) {
    if (_closing) return;
    _closing = true;
    final valid =
        identical(widget.controller.pendingConfirmation, widget.request) &&
        DateTime.now().isBefore(widget.request.deadline);
    Navigator.pop(context, approved && valid);
  }

  bool get _screenAccess => const {
    'act',
    'tapScreen',
    'captureScreen',
  }.contains(widget.request.call.name);

  @override
  Widget build(BuildContext context) => AuthorizationSheetContent(
    title: _screenAccess ? '允许读取和操作屏幕' : '操作确认',
    content: Text(widget.detail),
    allowLabel: _screenAccess
        ? '始终允许'
        : widget.request.definition.taskScopedConfirmation
        ? '本任务允许'
        : '允许一次',
    onAllow: () => _answer(true),
    onDeny: () => _answer(false),
    seconds:
        (widget.request.deadline.difference(DateTime.now()).inMilliseconds /
                1000)
            .ceil()
            .clamp(0, 30),
  );
}
