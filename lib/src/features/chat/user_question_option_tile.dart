import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';

class UserQuestionOptionTile extends StatelessWidget {
  const UserQuestionOptionTile({
    super.key,
    required this.option,
    required this.number,
    required this.selected,
    required this.onTap,
    this.multiple = false,
  });

  final UserQuestionOption option;
  final int number;
  final bool selected;
  final VoidCallback? onTap;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xffc4b5fd) : const Color(0xff7959df);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: !multiple,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: dark ? .19 : .14)
            : colors.onSurface.withValues(alpha: dark ? .08 : .045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected
                ? accent.withValues(alpha: .38)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.textScalerOf(context).scale(22),
                  height: MediaQuery.textScalerOf(context).scale(22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? colors.primary.withValues(alpha: .25)
                        : colors.onSurface.withValues(alpha: dark ? .12 : .08),
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
                          fontSize: option.title == null ? 16 : 14,
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
