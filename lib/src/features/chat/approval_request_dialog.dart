import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../storage/approval_center_store.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'question_icon.dart';

Future<void> showApprovalRequest(
  BuildContext context,
  ApprovalCenterStore store,
  Map<String, Object?> row,
) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .24),
  builder: (_) => _ApprovalDialog(store: store, row: row),
);

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.store, required this.row});
  final ApprovalCenterStore store;
  final Map<String, Object?> row;
  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late Map<String, Object?> _row = widget.row;
  bool _busy = false;
  late final StreamSubscription<void> _changes;
  @override
  void initState() {
    super.initState();
    _changes = ApprovalCenterStore.changes.stream.listen((_) {
      runUiAction(context, () async {
        final row = await widget.store.read(_row['id'] as String);
        if (mounted) setState(() => _row = row);
      });
    });
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  Future<void> _decide(String scope) async {
    setState(() => _busy = true);
    final ok = await runUiAction(
      context,
      () => widget.store.decide(_row, scope),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _row['status'] == 'pending';
    return AppDialog(
      maxWidth: 400,
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
                    '${_row['title']}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const QuestionIcon(type: QuestionIconType.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_row['sender_name']}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_row['description']}',
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                    if (_row['deadline'] != null && pending) ...[
                      const SizedBox(height: 12),
                      Text(
                        '截止 ${approvalTime(_row['deadline'] as int)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (pending) ...[
              DialogActionButton(
                text: _row['kind'] == 'miniapp' ? '批准加入' : '允许一次',
                loading: _busy,
                onPressed: _busy ? null : () => _decide('once'),
              ),
              if (_row['allow_scopes'] == 1)
                for (final scope in [
                  ('session', '当前会话允许'),
                  ('always', '始终允许'),
                ]) ...[
                  const SizedBox(height: 8),
                  DialogActionButton(
                    text: scope.$2,
                    role: DialogActionRole.secondary,
                    onPressed: _busy ? null : () => _decide(scope.$1),
                  ),
                ],
              const SizedBox(height: 8),
              DialogActionButton(
                text: '拒绝',
                role: DialogActionRole.reject,
                onPressed: _busy ? null : () => _decide('deny'),
              ),
            ] else
              DialogActionButton(
                text: approvalStatus(_row['status'] as String),
                role: DialogActionRole.secondary,
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

String approvalStatus(String status) => switch (status) {
  'pending' => '待处理',
  'approved' => '已批准',
  'denied' => '已拒绝',
  'expired' => '已超时',
  'cancelled' => '已取消',
  _ => status,
};
String approvalTime(int value) {
  final time = DateTime.fromMicrosecondsSinceEpoch(value).toLocal();
  return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class ApprovalPromptHost extends StatefulWidget {
  const ApprovalPromptHost({
    super.key,
    required this.store,
    required this.child,
  });
  final ApprovalCenterStore store;
  final Widget child;
  @override
  State<ApprovalPromptHost> createState() => _ApprovalPromptHostState();
}

class _ApprovalPromptHostState extends State<ApprovalPromptHost>
    with WidgetsBindingObserver {
  late final StreamSubscription<String> _requests;
  final _queue = <String>[];
  final _shown = <String>{};
  bool _showing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requests = ApprovalCenterStore.prompts.stream.listen((id) {
      if (_shown.add(id)) _queue.add(id);
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _next() async {
    if (!mounted ||
        _showing ||
        _queue.isEmpty ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final context = AppToasts.navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    _showing = true;
    try {
      await runUiAction(context, () async {
        final row = await widget.store.read(_queue.removeAt(0));
        if (context.mounted && row['status'] == 'pending')
          await showApprovalRequest(context, widget.store, row);
      });
    } finally {
      _showing = false;
      if (mounted && _queue.isNotEmpty) _schedule();
    }
  }

  @override
  void dispose() {
    _requests.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
