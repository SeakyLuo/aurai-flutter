import 'package:flutter/material.dart';

import 'question_icon.dart';

/// Clearing belongs to the text field and must not dismiss its keyboard.
class InputClearButton extends StatelessWidget {
  const InputClearButton({
    super.key,
    required this.onPressed,
    this.tooltip = '清空输入',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: ExcludeFocus(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: const QuestionIcon(type: QuestionIconType.close),
      ),
    ),
  );
}
