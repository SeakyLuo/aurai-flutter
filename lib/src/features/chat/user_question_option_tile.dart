import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import '../../app/global_ui.dart';
import 'settings_icon.dart';

class UserQuestionOptionTile extends StatelessWidget {
  const UserQuestionOptionTile({
    super.key,
    required this.option,
    required this.number,
    required this.selected,
    required this.onTap,
    this.multiple = false,
    this.vote = false,
  });

  final UserQuestionOption option;
  final int number;
  final bool selected;
  final VoidCallback? onTap;
  final bool multiple;
  final bool vote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = GlobalUI.highlightTextColor(context);
    final marked = multiple || vote;
    return Semantics(
      selected: selected,
      checked: marked ? selected : null,
      inMutuallyExclusiveGroup: !multiple,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: dark ? .19 : .14)
            : colors.onSurface.withValues(alpha: dark ? .08 : .045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(marked ? 16 : 24),
          side: BorderSide(
            color: selected
                ? accent.withValues(alpha: .38)
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
                if (!marked)
                  Container(
                    width: MediaQuery.textScalerOf(context).scale(22),
                    height: MediaQuery.textScalerOf(context).scale(22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? colors.primary.withValues(alpha: .25)
                          : colors.onSurface.withValues(
                              alpha: dark ? .12 : .08,
                            ),
                    ),
                    child: Text(
                      '$number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? accent
                            : colors.onSurface.withValues(alpha: .72),
                      ),
                    ),
                  ),
                if (!marked) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (option.title != null) ...[
                        Text(
                          option.title!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: selected && marked
                                ? accent
                                : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        option.content,
                        style: TextStyle(
                          fontSize: option.title == null ? 16 : 14,
                          height: 1.45,
                          fontWeight: selected && marked
                              ? FontWeight.w600
                              : null,
                          color: selected && marked
                              ? accent
                              : option.title == null
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (marked) ...[
                  const SizedBox(width: 16),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: multiple ? BorderRadius.circular(6) : null,
                      gradient: selected && multiple
                          ? GlobalUI.primaryGradient
                          : null,
                      border: selected && multiple
                          ? null
                          : Border.all(
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant.withValues(
                                      alpha: .6,
                                    ),
                              width: 1.65,
                            ),
                    ),
                    child: selected
                        ? multiple
                              ? const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: FittedBox(
                                    child: SettingsIcon(
                                      type: SettingsIconType.check,
                                      color: GlobalUI.onPrimary,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: GlobalUI.primaryGradient,
                                    ),
                                  ),
                                )
                        : null,
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
