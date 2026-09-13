import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'message_composer.dart';
import 'user_question_option_tile.dart';

class UserQuestionCard extends StatefulWidget {
  const UserQuestionCard({super.key, required this.question});
  final UserQuestion question;

  @override
  State<UserQuestionCard> createState() => _UserQuestionCardState();
}

class _UserQuestionCardState extends State<UserQuestionCard> {
  late final _text = TextEditingController(text: widget.question.draft);
  final _focus = FocusNode();
  bool _submitted = false;

  void _submit({bool skipped = false}) {
    if (_submitted) return;
    setState(() => _submitted = true);
    FocusScope.of(context).unfocus();
    widget.question.answer(skipped: skipped);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final question = widget.question;
    final canSend =
        !_submitted &&
        (_text.text.trim().isNotEmpty || question.selected != null);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: double.infinity,
          maxHeight: math.min(
            MediaQuery.sizeOf(context).height * 0.65,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.paddingOf(context).vertical -
                24,
          ),
        ),
        child: BackdropGroup(
          child: GlassSurface(
            radius: 24,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        QuestionIcon(
                          type: question.isUserAction
                              ? QuestionIconType.userAction
                              : QuestionIconType.question,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          question.isUserAction ? '等待你操作' : '问题',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: question.isUserAction ? '取消等待' : '跳过问题',
                          onPressed: _submitted
                              ? null
                              : () => _submit(skipped: true),
                          icon: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                question.question,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (question.isUserAction)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '操作完成后，请返回 Aurai 点“已完成”。遇到问题也可以在下方说明。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            for (var i = 0; i < question.options.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: UserQuestionOptionTile(
                                  option: question.optionAt(i),
                                  number: i + 1,
                                  selected: question.selected == i,
                                  onTap: _submitted
                                      ? null
                                      : () {
                                          question.selected = i;
                                          question.draft = '';
                                          _text.clear();
                                          _submit();
                                        },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    MessageComposer(
                      embedded: true,
                      controller: _text,
                      focusNode: _focus,
                      enabled: !_submitted,
                      hintText: question.isUserAction ? '说明遇到的问题' : '或自行撰写回复',
                      onChanged: (value) => setState(() {
                        question.draft = value;
                        question.selected = null;
                      }),
                      action: RoundAction(
                        label: '发送回答',
                        inkResponse: false,
                        primary: true,
                        compact: true,
                        icon: Icons.arrow_upward_rounded,
                        onPressed: canSend ? _submit : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
