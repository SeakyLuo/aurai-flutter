import 'package:flutter/material.dart';
import '../../domain/library_asset.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';

Future<void> showAssetInfo(BuildContext context, LibraryAsset asset) {
  final date = asset.createdAt;
  return showDialog<void>(
    context: context,
    builder: (context) => AppPromptDialog(
      title: asset.name,
      description:
          '${asset.source.label} · ${asset.sizeLabel}\n'
          '${date.year}年${date.month}月${date.day}日 '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}',
      actions: DialogActionButton(
        text: '关闭',
        role: DialogActionRole.secondary,
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );
}
