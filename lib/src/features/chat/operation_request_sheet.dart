import '../../domain/error_message.dart';
import '../../domain/agent_models.dart';
import '../../domain/ui_tool_actions.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'dialog_action_button.dart';
import 'question_icon.dart';
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
  late final Timer? _ticker;
  bool _closing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _ticker = widget.request.deadline == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    widget.request.completer.future.then((_) {
      if (mounted) _changed();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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

  Future<void> _answer(bool approved, [String scope = 'once']) async {
    if (_closing || _saving) return;
    if (widget.request.deadline != null &&
        !DateTime.now().isBefore(widget.request.deadline!)) {
      _closing = true;
      Navigator.pop(context, false);
      return;
    }
    if (approved && scope != 'once') {
      _saving = true;
      try {
        await widget.controller.toolApprovals.grant(
          widget.request.conversationId,
          widget.request.call,
          widget.request.call.name == 'runSkill'
              ? '技能：${widget.request.call.arguments['name']}（版本 ${widget.request.call.arguments['revision']}）'
              : toolTitle(widget.request.call.name),
          scope,
        );
      } catch (caughtError) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存授权失败，请重试：${errorMessage(caughtError)}')),
          );
        return;
      } finally {
        _saving = false;
      }
      if (!mounted) return;
    }
    widget.request.scope = 'once';
    if (_closing) return;
    _closing = true;
    final valid =
        identical(widget.controller.pendingConfirmation, widget.request) &&
        (widget.request.deadline == null ||
            DateTime.now().isBefore(widget.request.deadline!));
    Navigator.pop(context, approved && valid);
  }

  bool get _screenAccess => isScreenTool(widget.request.call.name);

  @override
  Widget build(BuildContext context) {
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
                      '${widget.detail}\n\n授权对象：${widget.request.call.name == 'runSkill' ? widget.request.call.arguments['name'] : toolTitle(widget.request.call.name)}${widget.request.deadline == null ? '' : '\n未处理将自动拒绝'}',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DialogActionButton(
                  text: '允许一次',
                  onPressed: () => _answer(true),
                ),
                if (!widget.request.definition.singleUseConfirmation) ...[
                  const SizedBox(height: 8),
                  DialogActionButton(
                    text: '当前会话允许',
                    role: DialogActionRole.secondary,
                    onPressed: () => _answer(true, 'session'),
                  ),
                  const SizedBox(height: 8),
                  DialogActionButton(
                    text: '始终允许',
                    role: DialogActionRole.secondary,
                    onPressed: () => _answer(true, 'always'),
                  ),
                ],
                const SizedBox(height: 8),
                DialogActionButton(
                  text: '拒绝',
                  role: DialogActionRole.reject,
                  detail: widget.request.deadline == null
                      ? null
                      : '${(widget.request.deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, widget.request.call.confirmationTimeoutSeconds!)} 秒后自动拒绝',
                  onPressed: () => _answer(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
