import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';
import 'conversation_menu_icon.dart';
import 'header_action_menu.dart';
import 'question_icon.dart';
import 'settings_icon.dart';

Future<String?> showAssetActionsMenu(
  BuildContext context, {
  Offset? position,
  required bool canLocate,
  required bool canManageAsset,
  bool trash = false,
  bool canInspect = false,
  bool canRemove = false,
}) => showHeaderActionMenu(
  context,
  position: position,
  destructiveValues: {'delete', 'remove'},
  separatorBeforeValues: {if (!trash) 'rename', 'delete', 'remove'},
  items: [
    if (trash)
      (
        value: 'restore',
        label: '恢复',
        icon: const QuestionIcon(type: QuestionIconType.undo),
      )
    else ...[
      (
        value: 'forward',
        label: '转发',
        icon: const AttachmentActionIcon(
          type: AttachmentActionIconType.forward,
        ),
      ),
      (
        value: 'save',
        label: '下载',
        icon: const AttachmentActionIcon(
          type: AttachmentActionIconType.download,
        ),
      ),
    ],
    if (canLocate)
      (
        value: 'locate',
        label: '定位消息',
        icon: const AttachmentActionIcon(type: AttachmentActionIconType.locate),
      ),
    if (canManageAsset && !trash)
      (
        value: 'rename',
        label: '重命名',
        icon: const ConversationMenuIcon(type: ConversationMenuIconType.rename),
      ),
    if (canManageAsset || canInspect)
      (
        value: 'info',
        label: '查看信息',
        icon: const SettingsIcon(type: SettingsIconType.info),
      ),
    if (canManageAsset)
      (
        value: 'delete',
        label: trash ? '彻底删除' : '移入回收站',
        icon: const ConversationMenuIcon(type: ConversationMenuIconType.delete),
      ),
    if (canRemove)
      (
        value: 'remove',
        label: '移除附件',
        icon: const ConversationMenuIcon(type: ConversationMenuIconType.delete),
      ),
  ],
);
