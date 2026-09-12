import 'shared_skill_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import 'extra_skill_icon.dart';
import 'package:flutter/material.dart';
import '../features/chat/tool_action_icon.dart';

export 'skill_icon_names.dart';

class SkillIcon extends StatelessWidget {
  const SkillIcon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) =>
      sharedSkillIcon(context, name) ??
      (name == 'settings'
          ? const SidebarActionIcon(type: SidebarActionIconType.settings)
          : ExtraSkillIcon.names.contains(name)
          ? ExtraSkillIcon(name)
          : name == 'code'
          ? CustomPaint(
              size: const Size.square(24),
              painter: _CodeIcon(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : ToolActionIcon(
              toolName: switch (name) {
                'news' => 'readFile',
                'search' => 'searchWeb',
                'calendar' => 'listScheduledTasks',
                'notification' => 'sendNotification',
                'file' => 'listFiles',
                'network' => 'getNetworkState',
                _ => 'runSkill',
              },
            ));
}

class _CodeIcon extends CustomPainter {
  const _CodeIcon(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(7, 7)
        ..lineTo(2, 12)
        ..lineTo(7, 17)
        ..moveTo(17, 7)
        ..lineTo(22, 12)
        ..lineTo(17, 17)
        ..moveTo(14, 4)
        ..lineTo(10, 20),
      pen,
    );
  }

  @override
  bool shouldRepaint(_CodeIcon old) => old.color != color;
}
