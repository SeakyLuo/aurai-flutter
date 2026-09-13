import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'skill_sort.dart';

Future<SkillSort?> showSkillSortPicker(
  BuildContext context,
  SkillSort selected,
) => showModalBottomSheet<SkillSort>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  barrierColor: Colors.black.withValues(alpha: .24),
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: GlassSurface(
        radius: 28,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        '排序',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const QuestionIcon(type: QuestionIconType.close),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final sort in SkillSort.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: settingsFieldColor(context),
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: Semantics(
                                selected: sort == selected,
                                inMutuallyExclusiveGroup: true,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context, sort),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            sort.label,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        SizedBox.square(
                                          dimension: 22,
                                          child: selected == sort
                                              ? DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: colors.onSurface,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: SettingsIcon(
                                                      type: SettingsIconType
                                                          .check,
                                                      color: colors.surface,
                                                    ),
                                                  ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
