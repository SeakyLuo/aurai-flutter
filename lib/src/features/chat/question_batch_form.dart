import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import 'question_navigation.dart';

import '../../agent/ask_user_tool.dart';
import '../../domain/message_sender.dart';
import '../../domain/question_batch.dart';
import '../../domain/selection_option.dart';
import 'interaction_text_preview.dart';
import 'message_composer.dart';
import 'question_message_heading.dart';
import 'question_response.dart';
import 'question_pager.dart';
import 'question_sheet.dart';
import 'user_question_option_tile.dart';
import 'glass_surface.dart';

class QuestionBatchController extends ChangeNotifier {
  QuestionBatchController(
    this.batch, {
    Map<String, Object?>? answers,
    this.index = 0,
  }) : answers = {...?answers};
  QuestionBatch batch;
  final Map<String, Object?> answers;
  int index;
  bool sending = false;
  void setSending(bool value) {
    sending = value;
    notifyListeners();
  }

  Map get currentAnswer =>
      answers[batch.questions[index]['id']] as Map? ?? const {};
  bool get complete => batch.questions.every(
    (q) => batch.accepts(q, answers[q['id']] as Map? ?? const {}),
  );

  void goTo(int value) {
    index = value;
    notifyListeners();
  }

  void answer(Map<String, Object?> value) {
    answers[batch.questions[index]['id'] as String] = value;
    notifyListeners();
  }
}

/// Shared question editor for native chat cards and blocking task sheets.
class QuestionBatchForm extends StatelessWidget {
  const QuestionBatchForm({
    super.key,
    required this.controller,
    this.onSubmit,
    this.busy = false,
    this.readOnly = false,
    this.compact = false,
    this.scrollable = false,
    this.focusInput = false,
    this.senderHeading,
    this.recipient,
    this.onOpenMember,
    this.trailing,
    this.status = '',
    this.closeWhen,
    this.submitLabel = '提交回答',
  });
  final QuestionBatchController controller;
  final Future<void> Function()? onSubmit;
  final bool busy, readOnly, compact;
  final bool scrollable;
  final bool focusInput;
  final Widget? senderHeading;
  final MessageSender? recipient;
  final ValueChanged<String>? onOpenMember;
  final Widget? trailing;
  final String status;
  final Future<void>? closeWhen;
  final String submitLabel;

  bool get _immediateAnswer =>
      controller.batch.questions.length == 1 &&
      controller.batch.questions.single['mode'] != 'multiple' &&
      !hasRichOptions(controller.batch.questions.single['options'] as List) &&
      controller.batch.questions.single['showConfirm'] != true;

  Future<void> _details(BuildContext context, {bool focusInput = false}) async {
    var submit = false;
    await showQuestionSheet(
      context,
      closeWhen: closeWhen,
      child: Builder(
        builder: (sheetContext) => QuestionSheetLayout(
          title: '问题',
          scrollBody: false,
          heading: const SizedBox.shrink(),
          child: QuestionBatchForm(
            scrollable: true,
            focusInput: focusInput,
            senderHeading: senderHeading,
            controller: controller,
            onSubmit: () async {
              submit = true;
              Navigator.of(sheetContext).pop();
            },
            busy: busy,
            readOnly: readOnly,
            recipient: recipient,
            onOpenMember: onOpenMember,
            status: status,
            trailing: trailing,
            closeWhen: closeWhen,
            submitLabel: submitLabel,
          ),
        ),
      ),
    );
    // Let the secondary sheet release its focus before completing its parent.
    if (submit && context.mounted) await onSubmit!();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final busy = this.busy || controller.sending;
      final questions = controller.batch.questions;
      final question = questions[controller.index];
      final answer = controller.currentAnswer;
      final options = question['options'] as List;
      final selected = (answer['selected'] as List? ?? const []).toSet();
      final text = answer['text'] as String? ?? '';
      final multiple = question['mode'] == 'multiple';
      final collapsed = compact && readOnly;
      final firstMissing = questions.indexWhere(
        (q) => !controller.batch.accepts(
          q,
          controller.answers[q['id']] as Map? ?? const {},
        ),
      );
      Future<void> advance() async {
        FocusScope.of(context).unfocus();
        if (controller.index < questions.length - 1) {
          controller.goTo(controller.index + 1);
        } else if (firstMissing >= 0) {
          controller.goTo(firstMissing);
          ScaffoldMessenger.of(
            context,
          ).showToast(SnackBar(content: Text('请完成第 ${firstMissing + 1} 题')));
        } else {
          await onSubmit!();
        }
      }

      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionMessageHeading(
            sheetHeader: !compact || scrollable,
            senderHeading: senderHeading,
            title: question['question'] as String,
            description: question['description'] as String? ?? '',
            multiple: multiple,
            modeLabel:
                '${question['mode'] == 'text'
                    ? '文字'
                    : multiple
                    ? '多选'
                    : '单选'}${!readOnly && questions.length > 1 ? ' · ${controller.index + 1}/${questions.length} 题' : ''}',
            status: status,
            recipient: recipient,
            onOpenMember: onOpenMember,
            trailing: trailing,
            pager: readOnly
                ? QuestionPager(
                    index: controller.index,
                    count: questions.length,
                    onChanged: (index) {
                      FocusScope.of(context).unfocus();
                      controller.goTo(index);
                    },
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (collapsed) ...[
            if (selected.isNotEmpty ||
                text.isNotEmpty ||
                answer['skipped'] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: QuestionResponse(
                  recipient: recipient,
                  onOpenMember: onOpenMember,
                  child: InteractionTextPreview(
                    text: answer['skipped'] == true
                        ? '已跳过'
                        : text.isNotEmpty
                        ? text
                        : options
                              .where((o) => selected.contains(o['id']))
                              .map((o) => o['label'])
                              .join('、'),
                    onShowDetails: () => _details(context),
                  ),
                ),
              ),
          ] else ...[
            QuestionAnswerContent(
              question: '',
              showQuestion: false,
              compactOptions: compact && !scrollable,
              onChooseOptions: () => _details(context),
              allowCustomAnswer:
                  compact &&
                  !scrollable &&
                  question['allowCustomAnswer'] == true,
              onCustomAnswer: readOnly || busy
                  ? null
                  : () => _details(context, focusInput: true),
              customAnswer: text,
              options: [
                for (final option in options)
                  UserQuestionOption.fromSelection(option as Map),
              ],
              selected: {
                for (final (i, option) in options.indexed)
                  if (selected.contains(option['id'])) i,
              },
              multiple: multiple,
              onSelect: readOnly || busy
                  ? null
                  : (i) async {
                      final next = {...selected};
                      if (!multiple) next.clear();
                      if (!next.remove(options[i]['id']))
                        next.add(options[i]['id']);
                      controller.answer({
                        'selected': next.toList(),
                        'text': '',
                        'skipped': false,
                      });
                      if (_immediateAnswer && controller.complete) {
                        await onSubmit!();
                      }
                    },
            ),
            if (readOnly && (text.isNotEmpty || answer['skipped'] == true))
              QuestionResponse(
                recipient: compact && !scrollable ? recipient : null,
                onOpenMember: onOpenMember,
                child: Text(
                  answer['skipped'] == true ? '已跳过' : text,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
          ],
        ],
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scrollable)
            Flexible(child: SingleChildScrollView(child: content))
          else
            content,
          if (compact && !scrollable && question['mode'] == 'text' && !readOnly)
            UserQuestionOptionTile(
              option: UserQuestionOption(
                content: text.isEmpty ? '自行撰写回复' : text,
              ),
              number: 1,
              selected: text.isNotEmpty,
              onTap: busy ? null : () => _details(context, focusInput: true),
            ),
          if ((question['mode'] == 'text' ||
                  question['allowCustomAnswer'] == true) &&
              !readOnly &&
              (!compact || scrollable))
            _QuestionTextInput(
              autofocus: focusInput,
              key: ValueKey(question['id']),
              text: text,
              enabled: !busy,
              hint: question['mode'] == 'text' ? '填写回答' : '或自行撰写回复',
              onSend: busy || text.trim().isEmpty ? null : advance,
              onChanged: (value) => controller.answer({
                'selected': <String>[],
                'text': value,
                'skipped': false,
              }),
            ),
          if (!readOnly) ...[
            if (question['required'] == false)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          controller.answer({
                            'selected': <String>[],
                            'text': '',
                            'skipped': true,
                          });
                          if (_immediateAnswer) await onSubmit!();
                        },
                  child: Text(answer['skipped'] == true ? '已跳过此题' : '跳过此题'),
                ),
              ),
            if (!_immediateAnswer) ...[
              const SizedBox(height: 12),
              QuestionNavigation(
                submitLabel: submitLabel,
                index: controller.index,
                count: questions.length,
                busy: busy,
                onPrevious: () {
                  FocusScope.of(context).unfocus();
                  controller.goTo(controller.index - 1);
                },
                onNext: advance,
              ),
            ],
          ],
        ],
      );
    },
  );
}

class _QuestionTextInput extends StatefulWidget {
  const _QuestionTextInput({
    super.key,
    required this.text,
    required this.enabled,
    required this.hint,
    required this.onChanged,
    required this.onSend,
    this.autofocus = false,
  });
  final String text, hint;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;
  @override
  State<_QuestionTextInput> createState() => _QuestionTextInputState();
}

class _QuestionTextInputState extends State<_QuestionTextInput> {
  late final _text = TextEditingController(text: widget.text);
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(_QuestionTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.text) _text.text = widget.text;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: MessageComposer(
      embedded: true,
      controller: _text,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLength: 2000,
      hintText: widget.hint,
      onChanged: widget.onChanged,
      action: RoundAction(
        label: '发送回答',
        inkResponse: false,
        primary: true,
        compact: true,
        icon: Icons.arrow_upward_rounded,
        onPressed: widget.onSend,
      ),
    ),
  );
}
