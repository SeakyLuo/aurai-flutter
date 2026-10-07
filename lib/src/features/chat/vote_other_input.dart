import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'question_icon.dart';
import 'question_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

Future<String?> showVoteOtherInput(
  BuildContext context, {
  required String title,
  required String initialText,
  required int maxLength,
  Future<void>? closeWhen,
}) async {
  String? result;
  await showQuestionSheet(
    context,
    closeWhen: closeWhen,
    child: Builder(
      builder: (context) => VoteOtherInput(
        title: title,
        initialText: initialText,
        maxLength: maxLength,
        onCancel: () => Navigator.pop(context),
        onComplete: (text) {
          result = text;
          FocusScope.of(context).unfocus();
          Navigator.pop(context);
        },
      ),
    ),
  );
  return result;
}

/// Used both as a standalone sheet and as the editing view of the option sheet.
class VoteOtherInput extends StatefulWidget {
  const VoteOtherInput({
    super.key,
    required this.title,
    required this.initialText,
    required this.maxLength,
    required this.onCancel,
    required this.onComplete,
  });

  final String title, initialText;
  final int maxLength;
  final VoidCallback onCancel;
  final ValueChanged<String> onComplete;

  @override
  State<VoteOtherInput> createState() => _VoteOtherInputState();
}

class _VoteOtherInputState extends State<VoteOtherInput> {
  late final _text = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuestionSheetLayout(
    title: '填写其他选项',
    trailing: SettingsGlassActionSurface(
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundAction(
              label: '返回',
              icon: Icons.close_rounded,
              iconWidget: const QuestionIcon(type: QuestionIconType.close),
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onCancel();
              },
            ),
            const VerticalDivider(width: 1, indent: 12, endIndent: 12),
            RoundAction(
              label: '完成',
              icon: Icons.check_rounded,
              iconWidget: SettingsIcon(
                type: SettingsIconType.check,
                color: SettingsGlassAction.foregroundColor(
                  context,
                  enabled: _text.text.trim().isNotEmpty,
                ),
              ),
              onPressed: _text.text.trim().isEmpty
                  ? null
                  : () => widget.onComplete(_text.text.trim()),
            ),
          ],
        ),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 17,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: '填写你的选项'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
  );
}
