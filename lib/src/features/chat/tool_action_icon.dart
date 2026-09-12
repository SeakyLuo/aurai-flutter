import 'package:flutter/material.dart';

import 'capability_icon.dart';
import 'file_tool_icon.dart';
import 'question_icon.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';

class ToolActionIcon extends StatelessWidget {
  const ToolActionIcon({super.key, this.toolName});
  final String? toolName;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 21,
    child: FittedBox(
      child: switch (toolName) {
        'getModelBalance' || 'openModelTopUp' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.balance,
        ),
        'prepareMemoryChanges' || 'applyMemoryChanges' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.memory,
        ),
        'listSkills' ||
        'readSkill' ||
        'createSkill' ||
        'updateSkill' ||
        'deleteSkill' ||
        'manageSkill' ||
        'runSkill' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.skills,
        ),
        'scheduledTask' ||
        'createScheduledTask' ||
        'updateScheduledTask' ||
        'listScheduledTasks' ||
        'pauseScheduledTask' ||
        'resumeScheduledTask' ||
        'deleteScheduledTask' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.tasks,
        ),
        'askUser' => const QuestionIcon(type: QuestionIconType.question),
        'searchTools' ||
        'searchWeb' ||
        'searchConversations' ||
        'searchMessages' ||
        'findApps' => SidebarActionIcon(
          type: SidebarActionIconType.search,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        'listFiles' ||
        'listDirectory' => const FileToolIcon(type: FileToolIconType.folder),
        'readWebPage' => CustomPaint(
          size: const Size.square(24),
          painter: _GlobePainter(
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        'readFile' ||
        'inspectLocalDatabase' ||
        'queryLocalDatabase' ||
        'readLocalDatabase' ||
        'inspectAndroidApi' => const FileToolIcon(type: FileToolIconType.read),
        'shell' || 'executeAndroidScript' => const CapabilityIcon(
          id: 'android.shell.app_uid',
        ),
        'captureScreen' => const CapabilityIcon(id: 'android.vision'),
        'clickUiElement' ||
        'inputUiText' ||
        'scrollUiForward' ||
        'scrollUiBackward' ||
        'goBack' ||
        'goHome' ||
        'act' ||
        'tapScreen' => const CapabilityIcon(id: 'screenAccess'),
        'observeDevice' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.device,
        ),
        'getNotifications' || 'sendNotification' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.notifications,
        ),
        'openSettings' => SidebarActionIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SidebarActionIconType.settings,
        ),
        'launchApp' ||
        'startIntent' => const CapabilityIcon(id: 'android.intents'),
        'requestAccessibilityAccess' => const CapabilityIcon(
          id: 'android.permissions',
        ),
        'getNetworkState' ||
        'getNetworkEvents' => const CapabilityIcon(id: 'android.network'),
        _ => CustomPaint(
          size: const Size.square(24),
          painter: _WrenchPainter(
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      },
    ),
  );
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter(this.color);
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
    canvas.drawCircle(const Offset(12, 12), 9, pen);
    canvas.drawOval(const Rect.fromLTRB(8, 3, 16, 21), pen);
    canvas.drawLine(const Offset(3, 12), const Offset(21, 12), pen);
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => oldDelegate.color != color;
}

class _WrenchPainter extends CustomPainter {
  const _WrenchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(14, 3.2)
        ..cubicTo(10.4, 3, 8.1, 6.4, 9.3, 9.6)
        ..lineTo(3.8, 15.1)
        ..cubicTo(.6, 18.3, 5.7, 23.4, 8.9, 20.2)
        ..lineTo(14.4, 14.7)
        ..cubicTo(17.6, 15.9, 21, 13.6, 20.8, 10)
        ..lineTo(17.7, 12)
        ..lineTo(14, 8.3)
        ..lineTo(14, 3.2)
        ..close(),
      pen,
    );
    canvas.drawCircle(const Offset(6, 18), .8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WrenchPainter oldDelegate) => oldDelegate.color != color;
}
