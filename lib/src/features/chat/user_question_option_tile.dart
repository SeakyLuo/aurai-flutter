import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'settings_icon.dart';
import 'selection_option_prefix.dart';
import 'question_option_appearance.dart';

class UserQuestionOptionTile extends StatelessWidget {
  const UserQuestionOptionTile({
    super.key,
    required this.option,
    required this.number,
    required this.selected,
    required this.onTap,
    this.multiple = false,
    this.showSelectionIndicator = true,
    this.vote = false,
    this.optionPrefix,
    this.fontSize,
    this.onIndicatorTap,
    this.contentMaxLines,
  });

  final UserQuestionOption option;
  final int number;
  final bool selected;
  final VoidCallback? onTap;
  final bool multiple;
  final bool showSelectionIndicator;
  final bool vote;
  final String? optionPrefix;
  final double? fontSize;
  final VoidCallback? onIndicatorTap;
  final int? contentMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = QuestionOptionAppearance.accent(context);
    final marked = multiple || vote;
    return Semantics(
      selected: selected,
      checked: marked && showSelectionIndicator ? selected : null,
      inMutuallyExclusiveGroup: showSelectionIndicator && !multiple,
      child: Material(
        color: selected
            ? QuestionOptionAppearance.selectedBackground(context)
            : colors.onSurface.withValues(alpha: dark ? .08 : .045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(marked ? 16 : 24),
          side: BorderSide(
            color: selected
                ? QuestionOptionAppearance.selectedBorder(context)
                : marked
                ? colors.outlineVariant
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(marked ? 16 : 24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!marked || optionPrefix != null) ...[
                  SelectionOptionPrefix(
                    number: number,
                    style: optionPrefix ?? 'number',
                    selected: selected,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (option.title != null) ...[
                        Text(
                          option.title!,
                          style: TextStyle(
                            fontSize: fontSize ?? 15,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        option.content,
                        maxLines: contentMaxLines,
                        overflow: contentMaxLines == null
                            ? null
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              fontSize ?? (option.title == null ? 16 : 14),
                          height: 1.45,
                          color: option.title == null
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (marked && showSelectionIndicator) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onIndicatorTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: multiple
                            ? BorderRadius.circular(6)
                            : null,
                        color: selected && multiple
                            ? QuestionOptionAppearance.selectedIndicator(
                                context,
                              )
                            : null,
                        border: selected && multiple
                            ? null
                            : Border.all(
                                color: selected
                                    ? accent
                                    : colors.onSurfaceVariant.withValues(
                                        alpha: .6,
                                      ),
                                width: 1.65,
                              ),
                      ),
                      child: selected
                          ? multiple
                                ? Padding(
                                    padding: EdgeInsets.all(3),
                                    child: FittedBox(
                                      child: SettingsIcon(
                                        type: SettingsIconType.check,
                                        color: accent,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                      ),
                                    ),
                                  )
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
