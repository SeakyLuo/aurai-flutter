import 'package:flutter/material.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_filter_menu.dart';

class SkillPageHeader extends StatelessWidget {
  const SkillPageHeader({
    super.key,
    required this.scope,
    required this.onScope,
  });
  final String scope;
  final ValueChanged<String> onScope;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('技能'),
      _choice(
        context,
        scope,
        const [
          (value: 'installed', label: '已安装'),
          (value: 'created', label: '我创建的'),
        ],
        '筛选技能',
        onScope,
      ),
    ],
  );
  Widget _choice(
    BuildContext context,
    String value,
    List<({String value, String label})> choices,
    String label,
    ValueChanged<String> onChanged,
  ) => Builder(
    builder: (anchor) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final box = anchor.findRenderObject()! as RenderBox;
        final selected = await showTaskChoiceMenu(
          context,
          anchor: box.localToGlobal(Offset.zero) & box.size,
          selected: value,
          label: label,
          centerOnAnchor: true,
          choices: choices,
        );
        if (context.mounted && selected != null) onChanged(selected);
      },
      child: Semantics(
        button: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 3, 5, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                choices.singleWhere((c) => c.value == value).label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 3),
              const RotatedBox(
                quarterTurns: 1,
                child: SizedBox.square(
                  dimension: 12,
                  child: FittedBox(
                    child: SettingsIcon(type: SettingsIconType.chevron),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
