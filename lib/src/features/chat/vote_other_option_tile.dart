import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'user_question_option_tile.dart';

class VoteOtherOptionTile extends StatelessWidget {
  const VoteOtherOptionTile({
    super.key,
    required this.text,
    required this.selected,
    required this.multiple,
    required this.number,
    required this.onEdit,
    required this.onToggle,
    this.fontSize,
    this.showSelectionIndicator = true,
    this.optionPrefix,
  });

  final String text;
  final bool selected, multiple;
  final bool showSelectionIndicator;
  final int number;
  final String? optionPrefix;
  final double? fontSize;
  final VoidCallback? onEdit, onToggle;

  @override
  Widget build(BuildContext context) => UserQuestionOptionTile(
    option: text.isEmpty
        ? const UserQuestionOption(content: '其他')
        : UserQuestionOption(title: '其他', content: text),
    number: number,
    optionPrefix: optionPrefix,
    multiple: multiple,
    vote: true,
    showSelectionIndicator: showSelectionIndicator,
    selected: selected,
    fontSize: fontSize,
    contentMaxLines: 1,
    onTap: onEdit,
    onIndicatorTap: onToggle,
  );
}
