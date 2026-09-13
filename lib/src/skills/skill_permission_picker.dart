import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
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
}) => showModalBottomSheet<SkillPermissionSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  barrierColor: Colors.black.withValues(alpha: .24),
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Expanded(
                        child: Text(
                          defaults ? '偏好权限' : '技能权限',
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
                                                        decoration:
                                                            BoxDecoration(
                                                              color: colors
                                                                  .onSurface,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                3,
                                                              ),
                                                          child: SettingsIcon(
                                                            type:
                                                                SettingsIconType
                                                                    .check,
                                                            color:
                                                                colors.surface,
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
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SkillPermissionSelection(
                                defaults ? SkillPermission.lowRisk : null,
                              ),
                            ),
                            child: Text(
                              defaults ? '恢复低风险默认' : '使用默认权限',
                              style: TextStyle(color: colors.onSurface),
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
      ),
    );
  },
);
