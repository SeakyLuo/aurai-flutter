import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';

class UserQuestionOptionTile extends StatelessWidget {
  const UserQuestionOptionTile({
    super.key,
    required this.option,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final UserQuestionOption option;
  final int number;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xffc4b5fd) : const Color(0xff7959df);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: dark ? .19 : .14)
            : colors.onSurface.withValues(alpha: dark ? .055 : .035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? accent.withValues(alpha: .38)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? colors.primary.withValues(alpha: .25)
                        : colors.onSurface.withValues(alpha: .045),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? accent : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        option.content,
                        style: TextStyle(
                          fontSize: option.title == null ? 15 : 14,
                          height: 1.45,
                          color: option.title == null
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
