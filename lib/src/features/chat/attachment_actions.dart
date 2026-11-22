import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

import '../../app/glass_notice.dart';
import '../../domain/agent_models.dart';
import '../../domain/error_message.dart';
import '../../domain/library_asset.dart';
import '../../domain/message_sender.dart';
import '../../domain/message_file.dart';
import '../../domain/message_summary.dart';
import '../../platform/preview_image_actions.dart';
import '../../platform/svg_image.dart';
import 'file_attachments.dart';
import 'asset_info_dialog.dart';
import 'asset_library_dialogs.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'image_action_scope.dart';
import 'image_actions_menu.dart';
import 'image_forward_page.dart';
import 'unavailable_image.dart';

Future<void> openAttachmentActions(
  BuildContext context,
  Offset position, {
  ImageProvider? image,
  MessageFile? file,
  String? imageName,
  String? imageMimeType,
  int? imageNumber,
  String? sourceMessageId,
  VoidCallback? onRemove,
  VoidCallback? onTrashed,
  bool allowAssetManagement = false,
}) async {
  final openMessageMenu = ImageMessageScope.messageMenuOf(context);
  if (openMessageMenu != null) {
    final imageLabel = imageNumber == null ? '[图片]' : '[第 $imageNumber 张图片]';
    final name = file?.name ?? imageName;
    await openMessageMenu(
      attachment: (
        context: context,
        quoteText: file != null
            ? MessageSummary.attachment(
                kind: 'file',
                mimeType: file.mimeType,
                name: file.name,
              )
            : name == null
            ? imageLabel
            : '$imageLabel $name',
        preview: (maxHeight) => file != null
            ? FileAttachmentCard(file: file)
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: image!,
                  fit: BoxFit.contain,
                  height: maxHeight.clamp(0.0, 260.0),
                  errorBuilder: (_, _, _) => const UnavailableImage(),
                ),
              ),
        copy: () => _copyAttachment(
          image: image,
          file: file,
          name: name,
          imageMimeType: imageMimeType,
        ),
      ),
    );
    return;
  }

  final controller = ImageActionScope.of(context);
  final library = controller.assetLibrary;
  final path = file?.path ?? (image is FileImage ? image.file.path : null);
  final canLocate =
      onRemove == null &&
      ImageMessageScope.of(context) == null &&
      (sourceMessageId != null || path != null);
  final messenger = ScaffoldMessenger.of(context);
  void notice(String text, ToastKind kind) =>
      messenger.showToast(SnackBar(content: Text(text)), kind: kind);

  try {
    final (origin, asset) = await (
      canLocate
          ? controller.imageOrigin(messageId: sourceMessageId, path: path)
          : Future<({String conversationId, String messageId})?>.value(),
      path != null
          ? library.activeAssetForPath(path)
          : Future<LibraryAsset?>.value(),
    ).wait;
    if (!context.mounted) return;
    final action = await showAssetActionsMenu(
      context,
      position: position,
      canLocate: origin != null,
      canManageAsset: allowAssetManagement && asset != null,
      canInspect: path != null,
      canRemove: onRemove != null,
    );
    if (!context.mounted) return;
    switch (action) {
      case 'forward':
        final sent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => file == null
                ? ImageForwardPage(controller: controller, image: image!)
                : ImageForwardPage.message(
                    controller: controller,
                    pageTitle: '转发文件',
                    message: AgentMessage(
                      id: newMessageId(),
                      role: AgentMessageRole.user,
                      senderId: MessageSender.localUser.id,
                      text: '',
                      files: [file],
                      createdAt: DateTime.now(),
                    ),
                  ),
          ),
        );
        if (sent == true && context.mounted) notice('已转发', ToastKind.success);
      case 'save':
        if (asset != null) {
          await library.download(asset);
        } else if (file != null) {
          await library.downloadFile(file.path, file.name);
        } else {
          await PreviewImageActions.perform(image!, 'save');
        }
        if (context.mounted) notice('已保存到应用下载目录', ToastKind.success);
      case 'locate':
        await openHomeConversation(
          context,
          controller,
          origin!.conversationId,
          messageId: origin.messageId,
        );
      case 'rename':
        final name = await showAssetRename(context, asset!.name);
        if (!context.mounted || name == null) return;
        await library.rename(asset, name);
        if (context.mounted) notice('已重命名', ToastKind.success);
      case 'info':
        if (asset != null) {
          await showAssetInfo(context, asset);
        } else if (file != null) {
          await showFileInfo(context, file);
        } else {
          final size = await (image as FileImage).file.length();
          if (context.mounted) await showImageInfo(context, size);
        }
      case 'delete':
        final confirmed = await confirmAssetTrash(context, 1);
        if (!context.mounted || confirmed != true) return;
        final ids = [asset!.id];
        await library.moveToTrash(ids);
        if (!context.mounted) return;
        onTrashed?.call();
        showAssetTrashed(messenger, () => library.restore(ids));
      case 'remove':
        onRemove!();
    }
  } on Object catch (error) {
    if (context.mounted) notice(errorMessage(error), ToastKind.error);
  }
}

Future<void> _copyAttachment({
  required ImageProvider? image,
  required MessageFile? file,
  required String? name,
  required String? imageMimeType,
}) async {
  final path = file?.path ?? (image is FileImage ? image.file.path : null);
  final bytes = path == null
      ? await PreviewImageActions.readBytes(image!)
      : null;
  final mime =
      file?.mimeType ??
      imageMimeType ??
      (bytes == null ? lookupMimeType(path!) : imageBytesMime(bytes));
  if (mime == null) throw const FormatException('无法识别附件格式');
  await const MethodChannel(
    'com.haiskynology.aurai/platform',
  ).invokeMethod<void>('copyChatAttachment', {
    'path': path,
    'bytes': bytes,
    'mimeType': mime,
    'name': name ?? '图片.${extensionFromMime(mime)}',
  });
}
