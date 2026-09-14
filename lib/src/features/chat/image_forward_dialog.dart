import '../../domain/error_message.dart';
import '../../domain/agent_models.dart';
import 'message_forward_preview.dart';
import 'unavailable_image.dart';
import '../../platform/message_image_store.dart';
import 'package:flutter/material.dart';
import '../../platform/preview_image_actions.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';

class ImageForwardDialog extends StatefulWidget {
  const ImageForwardDialog({
    super.key,
    required this.controller,
    required ImageProvider image,
    required this.targetId,
    required this.title,
  }) : image = image,
       message = null;
  const ImageForwardDialog.message({
    super.key,
    required this.controller,
    required AgentMessage message,
    required this.targetId,
    required this.title,
  }) : message = message,
       image = null;
  final ChatController controller;
  final ImageProvider? image;
  final AgentMessage? message;
  final String? targetId;
  final String title;
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
      if (widget.message case final message?) {
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
        _messenger.currentState!.showSnackBar(
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: GlassSurface(
              radius: 28,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '发送给',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    if (widget.message case final message?)
                      MessageForwardPreview(message: message)
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image(
                            image: widget.image!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.square(
                              dimension: 96,
                              child: UnavailableImage(),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '说点什么…',
                        filled: true,
                        fillColor: dialogControlColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
  );
}
