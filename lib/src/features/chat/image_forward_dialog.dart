import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/agent_models.dart';
import 'message_forward_preview.dart';
import 'forward_conversation_sheet.dart';
import 'settings_icon.dart';
import 'unavailable_image.dart';
import '../../platform/message_image_store.dart';
import 'package:flutter/material.dart';
import '../../platform/preview_image_actions.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import 'glass_surface.dart';

class ImageForwardDialog extends StatefulWidget {
  const ImageForwardDialog({
    super.key,
    required this.controller,
    required ImageProvider image,
    required this.targetId,
    required this.kind,
    required this.title,
    required this.recipientName,
    required this.avatar,
  }) : image = image,
       message = null,
       sendMessage = null,
       preview = null;
  const ImageForwardDialog.message({
    super.key,
    required this.controller,
    required AgentMessage message,
    this.sendMessage,
    this.preview,
    required this.targetId,
    required this.kind,
    required this.title,
    required this.recipientName,
    required this.avatar,
  }) : message = message,
       image = null;
  final ChatController controller;
  final ImageProvider? image;
  final AgentMessage? message;
  final Widget? preview;
  final Future<void> Function(String? targetId, String note)? sendMessage;
  final String? targetId;
  final ConversationKind kind;
  final String title;
  final String recipientName;
  final Widget avatar;
  @override
  State<ImageForwardDialog> createState() => _ImageForwardDialogState();
}

class _ImageForwardDialogState extends State<ImageForwardDialog> {
  final _text = TextEditingController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _sending = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (widget.sendMessage case final send?) {
        await send(widget.targetId, _text.text.trim());
      } else if (widget.message case final message?) {
        await widget.controller.forwardMessage(
          widget.targetId,
          message,
          _text.text.trim(),
        );
      } else {
        final bytes = await PreviewImageActions.readBytes(widget.image!);
        await widget.controller.forwardImage(
          widget.targetId,
          bytes,
          _text.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _messenger.currentState!.showGlassSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : error is ImageInputException
                  ? error.message
                  : '转发失败，请重试：${errorMessage(error)}',
            ),
          ),
        );
      }
    }
  }

  Widget _content({required bool bounded}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '发送给',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _sending || widget.targetId == null
            ? null
            : () {
                FocusScope.of(context).unfocus();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: false,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ForwardConversationSheet(
                    controller: widget.controller,
                    conversationId: widget.targetId!,
                    kind: widget.kind,
                    title: widget.title,
                  ),
                );
              },
        child: Row(
          children: [
            widget.avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.targetId != null) ...[
              const SizedBox(width: 12),
              const SettingsIcon(type: SettingsIconType.chevron),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (widget.preview != null)
        widget.preview!
      else if (bounded)
        Flexible(
          child: MessageForwardPreview(
            message: widget.message!,
            enabled: !_sending,
            fitAvailableHeight: true,
          ),
        )
      else if (widget.message != null)
        MessageForwardPreview(message: widget.message!, enabled: !_sending)
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dialogControlColor(context),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: widget.image!,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.square(
                dimension: 88,
                child: UnavailableImage(),
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _text,
        enabled: !_sending,
        minLines: 1,
        maxLines: bounded ? 1 : 3,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: '留言',
          filled: true,
          fillColor: dialogControlColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight.clamp(
          0.0,
          widget.message?.htmlGame != null ? 520.0 : 400.0,
        ),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: PopScope(
            canPop: !_sending,
            child: ScaffoldMessenger(
              key: _messenger,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: widget.message?.htmlGame != null
                              ? _content(bounded: true)
                              : SingleChildScrollView(
                                  child: _content(bounded: false),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: DialogActionButton(
                                text: '取消',
                                role: DialogActionRole.secondary,
                                onPressed: _sending
                                    ? null
                                    : () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DialogActionButton(
                                text: _sending ? '发送中…' : '发送',
                                onPressed: _sending ? null : _send,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
