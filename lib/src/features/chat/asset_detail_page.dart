import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/library_asset.dart';
import '../../platform/message_file_store.dart';
import '../../platform/svg_image.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'file_type_icon.dart';
import 'home_navigation.dart';
import 'image_action_scope.dart';
import 'image_preview.dart';
import 'settings_appearance.dart';
import 'unavailable_image.dart';

class AssetDetailPage extends StatefulWidget {
  const AssetDetailPage({
    super.key,
    required this.asset,
    required this.controller,
    required this.onUse,
    required this.onSave,
    required this.onRestore,
    required this.trash,
  });
  final LibraryAsset asset;
  final ChatController controller;
  final Future<void> Function() onUse, onSave, onRestore;
  final bool trash;
  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  bool _busy = false;
  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final provider = localImageProvider(widget.asset.path);
    final size = await loadPreviewImageSize(provider, context);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageActionScope(
          controller: widget.controller,
          child: ImagePreview(
            images: [provider],
            initialIndex: 0,
            heroTag: 'asset:${widget.asset.id}',
            imageSize: size,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final date = asset.createdAt;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '资产详情',
          onBack: _busy ? null : () => Navigator.pop(context),
        ),
        body: SettingsPageBody(
          avoidHeader: true,
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (asset.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: GestureDetector(
                            onTap: _busy ? null : () => _perform(_preview),
                            child: Image(
                              image: localImageProvider(asset.path),
                              height: 280,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stack) =>
                                  const UnavailableImage(),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 160,
                          child: Center(
                            child: SizedBox.square(
                              dimension: 64,
                              child: FittedBox(
                                child: FileTypeIcon(file: asset.file),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        asset.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${asset.source.label} · ${asset.sizeLabel}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (asset.conversationId != null &&
                          asset.messageId != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _perform(
                                    () => openHomeConversation(
                                      context,
                                      widget.controller,
                                      asset.conversationId!,
                                      messageId: asset.messageId!,
                                    ),
                                  ),
                            child: const Text('查看来源会话'),
                          ),
                        ),
                      const SizedBox(height: 28),
                      if (!asset.isImage) ...[
                        DialogActionButton(
                          text: '打开文件',
                          role: DialogActionRole.secondary,
                          onPressed: _busy
                              ? null
                              : () => _perform(
                                  () => MessageFileStore.open(asset.file),
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      DialogActionButton(
                        text: widget.trash ? '恢复到资料库' : '用于聊天',
                        onPressed: _busy
                            ? null
                            : () => _perform(() async {
                                if (widget.trash) {
                                  await widget.onRestore();
                                  if (mounted) Navigator.pop(context);
                                } else {
                                  await widget.onUse();
                                }
                              }),
                      ),
                      if (!widget.trash) ...[
                        const SizedBox(height: 12),
                        DialogActionButton(
                          text: '保存到设备',
                          role: DialogActionRole.secondary,
                          onPressed: _busy
                              ? null
                              : () => _perform(widget.onSave),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
