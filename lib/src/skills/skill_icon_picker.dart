import '../features/chat/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/question_icon.dart';
import 'skill_icon.dart';

Future<String?> showSkillIconPicker(
  BuildContext context,
  String selected, {
  String title = '选择技能图标',
}) {
  final media = MediaQuery.of(context);
  final height = media.size.height - media.viewPadding.top;
  return showAppBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: Colors.black.withValues(alpha: .24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) => SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: skillIconChoices.length,
                itemBuilder: (context, index) {
                  final entry = skillIconChoices.entries.elementAt(index);
                  final isSelected = selected == entry.key;
                  return Semantics(
                    label: entry.value,
                    selected: isSelected,
                    button: true,
                    child: Material(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, entry.key),
                        child: Center(
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                            child: SkillIcon(entry.key),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
