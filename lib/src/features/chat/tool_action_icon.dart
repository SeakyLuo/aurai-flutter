import 'package:flutter/material.dart';

import 'capability_icon.dart';
import 'wrench_painter.dart';
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
        'sendHtmlMessage' ||
        'sendInteractiveMessage' ||
        'findContacts' ||
        'listFriends' ||
        'addFriend' ||
        'readExecutionLogs' ||
        'readInteractiveMessage' ||
        'updateInteractiveMessage' ||
        'createConversation' ||
        'renameConversation' ||
        'setConversationPinned' ||
        'setConversationArchived' ||
        'deleteConversation' ||
        'sendConversationMessage' ||
        'openAppPage' ||
        'listGroupChats' ||
        'readGroupChat' ||
        'sendGroupMessage' ||
        'recallMessage' ||
        'createGroupChat' ||
        'renameGroupChat' ||
        'updateGroupChatMembers' ||
        'listAiContacts' ||
        'readAiContact' ||
        'readMyProfile' ||
        'updateMyProfile' ||
        'createAiContact' ||
        'updateAiContact' ||
        'deleteAiContact' ||
        'restoreAiContact' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.contacts,
        ),
        'getModelBalance' || 'openModelTopUp' => SettingsIcon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          type: SettingsIconType.balance,
        ),
        'listMemories' ||
        'readMemory' ||
        'createMemory' ||
        'updateMemory' ||
        'deleteMemory' ||
        'prepareMemoryChanges' ||
        'applyMemoryChanges' => SettingsIcon(
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
        'searchImages' ||
        'searchWeb' ||
        'searchConversations' ||
        'readMessage' ||
        'readMessageAttachment' ||
        'readGroupMessages' ||
        'searchMessages' ||
        'findApps' => SidebarActionIcon(
          type: SidebarActionIconType.search,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        'getDocumentFolders' ||
        'requestDocumentFolder' ||
        'searchFiles' ||
        'listFiles' ||
        'listDirectory' => const FileToolIcon(type: FileToolIconType.folder),
        'readWebPage' || 'setSourceDates' => CustomPaint(
          size: const Size.square(24),
          painter: _GlobePainter(
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        'readAttachment' ||
        'readDocument' ||
        'createTextFile' ||
        'shareFile' ||
        'readFile' ||
        'inspectLocalDatabase' ||
        'queryLocalDatabase' ||
        'readLocalDatabase' ||
        'inspectAndroidApi' => const FileToolIcon(type: FileToolIconType.read),
        'shell' || 'executeShizuku' || 'executeAndroidScript' =>
          const CapabilityIcon(id: 'android.shell.app_uid'),
        'requestShizukuAccess' => const CapabilityIcon(
          id: 'android.permissions',
        ),
        'getDeviceExtensions' ||
        'startNetworkCapture' ||
        'stopNetworkCapture' ||
        'readNetworkTraffic' ||
        'clearNetworkTraffic' => const CapabilityIcon(id: 'android.network'),
        'captureScreen' => const CapabilityIcon(id: 'android.vision'),
        'clickUiElement' ||
        'inputUiText' ||
        'scrollUiForward' ||
        'scrollUiBackward' ||
        'goBack' ||
        'goHome' ||
        'act' ||
        'tapScreen' => const CapabilityIcon(id: 'screenAccess'),
        'observeDevice' || 'waitForUi' => SettingsIcon(
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
          painter: WrenchPainter(
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
