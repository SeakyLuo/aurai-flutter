import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/question_icon.dart';
import 'skill_icon.dart';

Future<String?> showSkillIconPicker(BuildContext context, String selected) {
  final media = MediaQuery.of(context);
  final height = media.size.height - media.viewPadding.top;
  return showModalBottomSheet<String>(
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
                  const Expanded(
                    child: Text(
                      '选择技能图标',
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
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100,
                  mainAxisExtent:
                      48 + MediaQuery.textScalerOf(context).scale(13) * 2.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: skillIcons.length,
                itemBuilder: (context, index) {
                  final entry = skillIcons.entries.elementAt(index);
                  return Semantics(
                    selected: selected == entry.key,
                    button: true,
                    child: Material(
                      color: selected == entry.key
                          ? settingsFieldColor(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, entry.key),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                              child: SkillIcon(entry.key),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
