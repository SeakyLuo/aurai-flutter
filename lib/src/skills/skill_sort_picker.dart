import '../features/chat/app_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../features/chat/question_icon.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'skill_sort.dart';

Future<SkillSort?> showSkillSortPicker(
  BuildContext context,
  SkillSort selected,
) {
  return showAppBottomSheet<SkillSort>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '排序',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              for (final sort in SkillSort.values)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: sort == SkillSort.values.last ? 0 : 10,
                  ),
                  child: Semantics(
                    selected: selected == sort,
                    inMutuallyExclusiveGroup: true,
                    child: Material(
                      color: settingsFieldColor(context),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, sort),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sort.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 22,
                                height: 22,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected == sort
                                      ? colors.onSurface
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected == sort
                                        ? colors.onSurface
                                        : colors.outline,
                                    width: 1.4,
                                  ),
                                ),
                                child: selected == sort
                                    ? SettingsIcon(
                                        type: SettingsIconType.check,
                                        color: colors.surface,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
