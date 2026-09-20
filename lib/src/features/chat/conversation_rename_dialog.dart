import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

import 'dialog_action_button.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

class ConversationRenameDialog extends StatefulWidget {
  const ConversationRenameDialog({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.initialTitle,
  });
  final ChatController controller;
  final String conversationId;
  final String initialTitle;

  @override
  State<ConversationRenameDialog> createState() =>
      _ConversationRenameDialogState();
}

class _ConversationRenameDialogState extends State<ConversationRenameDialog> {
  late final _text = TextEditingController(text: widget.initialTitle);
  bool _saving = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      _messenger.currentState!.showGlassSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_saving) return;
    if (_text.text.trim().isEmpty) {
      _notice('请输入会话名称');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.renameConversation(
        widget.conversationId,
        _text.text,
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _notice('重命名失败，请重试：${errorMessage(error)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: GlassSurface(
                radius: 28,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '重命名会话',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: dialogControlColor(context),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: TextField(
                          controller: _text,
                          autofocus: true,
                          enabled: !_saving,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.4,
                            color: colors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: '会话名称',
                            filled: false,
                            suffixIcon: _text.text.isEmpty
                                ? null
                                : RoundAction(
                                    icon: Icons.cancel,
                                    iconWidget: const QuestionIcon(
                                      type: QuestionIconType.close,
                                    ),
                                    compact: true,
                                    inkResponse: false,
                                    label: '清空会话名称',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(_text.clear),
                                  ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _save(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: DialogActionButton(
                              text: '取消',
                              role: DialogActionRole.secondary,
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DialogActionButton(
                              text: '保存',
                              loading: _saving,
                              onPressed: _saving || _text.text.trim().isEmpty
                                  ? null
                                  : _save,
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
}
