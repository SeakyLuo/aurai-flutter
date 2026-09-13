import '../../domain/ui_tool_actions.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'chat_controller.dart';

Future<bool> showOperationRequestSheet(
  BuildContext context, {
  required ChatController controller,
  required PendingConfirmation request,
  required String detail,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
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

  bool get _screenAccess => isScreenTool(widget.request.call.name);

  Widget _option(String label, VoidCallback onTap, {String? description}) =>
      Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final seconds =
        (widget.request.deadline.difference(DateTime.now()).inMilliseconds /
                1000)
            .ceil()
            .clamp(0, widget.request.call.confirmationTimeoutSeconds!);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GlassSurface(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _screenAccess ? '允许读取和操作屏幕' : '操作确认',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '拒绝并关闭',
                      onPressed: () => _answer(false),
                      icon: const QuestionIcon(type: QuestionIconType.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      widget.detail,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _option(
                  _screenAccess
                      ? '始终允许'
                      : widget.request.definition.taskScopedConfirmation
                      ? '本任务允许'
                      : '允许一次',
                  () => _answer(true),
                ),
                const SizedBox(height: 8),
                _option(
                  '拒绝',
                  () => _answer(false),
                  description: '$seconds 秒后自动拒绝',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
