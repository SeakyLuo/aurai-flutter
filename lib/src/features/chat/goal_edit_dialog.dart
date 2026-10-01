import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';

class GoalEditDialog extends StatefulWidget {
  const GoalEditDialog({
    super.key,
    required this.objective,
    required this.running,
    required this.onSave,
    this.tokenBudget,
  });
  final String objective;
  final bool running;
  final Future<void> Function(String, int?) onSave;
  final int? tokenBudget;

  @override
  State<GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<GoalEditDialog> {
  late final _text = TextEditingController(text: widget.objective);
  late final _budget = TextEditingController(
    text: widget.tokenBudget?.toString() ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await runUiAction(context, () {
      final text = _budget.text.trim();
      final budget = text.isEmpty ? null : int.tryParse(text);
      if (text.isNotEmpty && (budget == null || budget <= 0))
        throw ArgumentError('Token 预算请输入正整数，留空为不限');
      return widget.onSave(_text.text.trim(), budget);
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      maxWidth: 520,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '编辑目标',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: dialogControlColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _text,
                autofocus: true,
                enabled: !_saving,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '希望达成什么目标',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: dialogControlColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _budget,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Token 预算',
                  hintText: '留空为不限',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.running) ...[
              const SizedBox(height: 12),
              Text(
                '保存后暂停当前执行，可从目标菜单继续。',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DialogActionButton(
                    text: '取消',
                    role: DialogActionRole.secondary,
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DialogActionButton(
                    text: '保存',
                    loading: _saving,
                    onPressed:
                        _saving ||
                            _text.text.trim().isEmpty ||
                            (_text.text.trim() == widget.objective &&
                                _budget.text.trim() ==
                                    (widget.tokenBudget?.toString() ?? ''))
                        ? null
                        : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
