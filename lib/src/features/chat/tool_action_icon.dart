import '../../skills/skill_icon.dart';
import '../../domain/tool_customization.dart';
import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';

import 'capability_icon.dart';
import 'conversation_icon.dart';
import 'wrench_painter.dart';
import 'file_tool_icon.dart';
import 'question_icon.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';
import 'tool_semantic_icon.dart';

class ToolActionIcon extends StatelessWidget {
  const ToolActionIcon({super.key, this.toolName, this.iconName});
  final String? toolName;
  final String? iconName;
  String? get _icon {
    final selected = iconName ?? ToolCustomizations.values[toolName]?.icon;
    return selected == null || selected.isEmpty ? toolName : selected;
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 21,
    child: FittedBox(
      child: _icon?.startsWith('skill:') == true
          ? SkillIcon(_icon!.substring(6))
          : switch (_icon) {
              'sendHtmlMessage' ||
              'readHtmlMessage' ||
              'updateHtmlMessage' => AttachmentActionIcon(
                type: AttachmentActionIconType.html,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              'listHtmlApps' ||
              'listHtmlAppPublications' ||
              'readHtmlAppPublication' ||
              'publishHtmlApp' ||
              'updateHtmlAppPublication' ||
              'setHtmlAppIcon' ||
              'withdrawHtmlApp' => SettingsIcon(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                type: SettingsIconType.miniapps,
              ),
              'sendInteractiveMessage' ||
              'clickInteractiveMessage' ||
              'retryInteractiveCallback' ||
              'readInteractiveMessage' ||
              'updateInteractiveMessage' ||
              'createConversation' ||
              'renameConversation' ||
              'setConversationPinned' ||
              'setConversationArchived' ||
              'deleteConversation' ||
              'sendConversationMessage' ||
              'readMessage' ||
              'locateMessage' ||
              'forwardMessage' ||
              'sendQuickReply' ||
              'recallMessage' => const ConversationIcon(),
              'wakeGroupMember' ||
              'sleepGroupChat' ||
              'listGroupChats' ||
              'readGroupChat' ||
              'readGroupMessages' ||
              'sendGroupMessage' ||
              'createGroupChat' ||
              'renameGroupChat' ||
              'updateGroupChatMembers' => SidebarActionIcon(
                type: SidebarActionIconType.group,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              'findContacts' ||
              'listFriends' ||
              'addFriend' ||
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
              'getModelConfiguration' ||
              'openModelConfiguration' => SettingsIcon(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                type: SettingsIconType.model,
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
              'searchSkills' ||
              'enableSkill' ||
              'disableSkill' ||
              'listSkills' ||
              'readSkill' ||
              'createSkill' ||
              'updateSkill' ||
              'deleteSkill' ||
              'installSkill' ||
              'uninstallSkill' ||
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
              'searchMessages' => SidebarActionIcon(
                type: SidebarActionIconType.search,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              'searchImages' || 'generateImage' => const ToolSemanticIcon(
                type: ToolSemanticIconType.imageSearch,
              ),
              'generateMusic' => AttachmentActionIcon(
                type: AttachmentActionIconType.audio,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              'findApps' => const ToolSemanticIcon(
                type: ToolSemanticIconType.appSearch,
              ),
              'getDocumentFolders' ||
              'requestDocumentFolder' ||
              'searchFiles' ||
              'listFiles' ||
              'listDirectory' => const FileToolIcon(
                type: FileToolIconType.folder,
              ),
              'readWebPage' => const SkillIcon('browser'),
              'setSourceDates' => const SkillIcon('calendar'),
              'readAttachment' ||
              'readMessageAttachment' ||
              'readExecutionLogs' ||
              'readDocument' ||
              'readFile' ||
              'inspectLocalDatabase' ||
              'queryLocalDatabase' ||
              'readLocalDatabase' => const FileToolIcon(
                type: FileToolIconType.read,
              ),
              'createTextFile' => const ToolSemanticIcon(
                type: ToolSemanticIconType.createFile,
              ),
              'shareFile' => const ToolSemanticIcon(
                type: ToolSemanticIconType.shareFile,
              ),
              'inspectAndroidApi' => const SkillIcon('code'),
              'shell' || 'executeShizuku' || 'executeAndroidScript' =>
                const CapabilityIcon(id: 'android.shell.app_uid'),
              'requestShizukuAccess' => const CapabilityIcon(
                id: 'android.permissions',
              ),
              'getDeviceExtensions' => SettingsIcon(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                type: SettingsIconType.device,
              ),
              'startNetworkCapture' ||
              'stopNetworkCapture' ||
              'readNetworkTraffic' ||
              'clearNetworkTraffic' => const CapabilityIcon(
                id: 'android.network',
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
              'openAppPage' => const CapabilityIcon(id: 'android.apps'),
              'launchApp' ||
              'startIntent' => const CapabilityIcon(id: 'android.intents'),
              'requestAccessibilityAccess' => const CapabilityIcon(
                id: 'android.permissions',
              ),
              'getNetworkState' ||
              'getNetworkEvents' ||
              'dnsLookup' ||
              'httpProbe' ||
              'tlsProbe' => const CapabilityIcon(id: 'android.network'),
              'wait' => const SkillIcon('clock'),
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
