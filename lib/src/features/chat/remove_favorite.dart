import '../../app/glass_notice.dart';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../storage/starred_messages.dart';

Future<void> removeFavorite(
  BuildContext context,
  StarredMessages store,
  String messageId, {
  VoidCallback? onRemoved,
  VoidCallback? onRestored,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final timestamp = await store.removeForUndo(messageId);
  onRemoved?.call();
  if (!messenger.mounted || timestamp == null) return;
  messenger.showGlassSnackBar(
    SnackBar(
      content: const Text('已取消收藏'),
      persist: false,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () async {
          try {
            await store.set(messageId, true, starredAt: timestamp);
            onRestored?.call();
            if (messenger.mounted)
              messenger.showGlassSnackBar(const SnackBar(content: Text('已恢复收藏')));
          } on Object catch (error) {
            if (messenger.mounted)
              messenger.showGlassSnackBar(
                SnackBar(content: Text('恢复收藏失败：${errorMessage(error)}')),
              );
          }
        },
      ),
    ),
  );
}
