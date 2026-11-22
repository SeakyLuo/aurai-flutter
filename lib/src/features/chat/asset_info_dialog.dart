import 'package:flutter/material.dart';
import '../../domain/library_asset.dart';
import '../../domain/message_file.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';

Future<void> showAssetInfo(BuildContext context, LibraryAsset asset) {
  final date = asset.createdAt;
  return _showInfo(
    context,
    asset.name,
    '${asset.source.label} · ${asset.sizeLabel}\n'
    '${date.year}年${date.month}月${date.day}日 '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}',
  );
}

Future<void> showFileInfo(BuildContext context, MessageFile file) =>
    _showInfo(context, file.name, '文件 · ${file.sizeLabel}');

Future<void> showImageInfo(BuildContext context, int size) =>
    _showInfo(context, '图片', attachmentSizeLabel(size));

Future<void> _showInfo(
  BuildContext context,
  String title,
  String description,
) => showDialog<void>(
  context: context,
  builder: (context) => AppPromptDialog(
    title: title,
    description: description,
    actions: DialogActionButton(
      text: '关闭',
      role: DialogActionRole.secondary,
      onPressed: () => Navigator.pop(context),
    ),
  ),
);
