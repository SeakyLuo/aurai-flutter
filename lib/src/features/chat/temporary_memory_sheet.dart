import 'app_bottom_sheet.dart';
import 'package:flutter/material.dart';

import 'question_icon.dart';
import 'settings_appearance.dart';
import 'visibility_option_tile.dart';

Future<bool?> showTemporaryMemorySheet(
  BuildContext context, {
  required bool personalized,
}) => showAppBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SettingsGlassAction(
                label: '关闭',
                icon: Icons.close_rounded,
                iconWidget: const QuestionIcon(type: QuestionIconType.close),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  '使用记忆',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 16),
          VisibilityOptionTile(
            title: '使用记忆',
            subtitle: '使用已有记忆和自定义指令',
            selected: personalized,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          VisibilityOptionTile(
            title: '不使用记忆',
            subtitle: '不使用记忆和自定义指令',
            selected: !personalized,
            onTap: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '临时聊天不写入新记忆，也不参与会话搜索。发送后的记录会在退出时归档。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
