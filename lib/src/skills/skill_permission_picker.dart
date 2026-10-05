import '../features/chat/app_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../features/chat/question_icon.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'skill_permission.dart';

class SkillPermissionSelection {
  const SkillPermissionSelection(this.permission);
  final SkillPermission? permission;
}

Future<SkillPermissionSelection?> showSkillPermissionPicker(
  BuildContext context,
  SkillPermission selected, {
  bool defaults = false,
}) => showAppBottomSheet<SkillPermissionSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Text(
                        defaults ? '偏好权限' : '技能权限',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SettingsGlassAction(
                          label: '关闭',
                          icon: Icons.close_rounded,
                          iconWidget: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SettingsGlassAction(
                          label: defaults ? '恢复低风险默认' : '使用默认权限',
                          icon: Icons.restart_alt_rounded,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.reset,
                          ),
                          onPressed: () => Navigator.pop(
                            context,
                            SkillPermissionSelection(
                              defaults ? SkillPermission.lowRisk : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final permission in SkillPermission.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: settingsFieldColor(context),
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: Semantics(
                                selected: selected == permission,
                                inMutuallyExclusiveGroup: true,
                                child: InkWell(
                                  onTap: () => Navigator.pop(
                                    context,
                                    SkillPermissionSelection(permission),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                permission.label,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            SizedBox.square(
                                              dimension: 22,
                                              child: selected == permission
                                                  ? DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: colors.onSurface,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              3,
                                                            ),
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
                                        const SizedBox(height: 6),
                                        Text(
                                          permission.description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.45,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                          child: Text(
                            '技能脚本按高风险操作处理，只有允许所有操作才会免确认执行。依赖技能分别遵循自己的权限；说明型技能使用其他工具时，仍遵循那些工具的权限。设备系统权限仍需开启。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: colors.onSurfaceVariant,
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
