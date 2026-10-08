import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import '../../domain/question_batch.dart';
import '../../storage/interactive_selection_drafts.dart';
import 'question_batch_form.dart';
import '../../agent/ask_user_tool.dart';
import 'question_card_anchor.dart';
import 'question_sheet.dart';
import 'user_question_card.dart';

class QuestionBatchCard extends StatefulWidget {
  const QuestionBatchCard({
    super.key,
    required this.questions,
    required this.buttonId,
    required this.actorId,
    required this.version,
    required this.readOnly,
    required this.status,
    required this.onSubmit,
    required this.onSave,
    this.messageId,
    this.answer,
    this.recipient,
    this.onOpenMember,
    this.trailing,
    this.compact = true,
  });
  final List questions;
  final String buttonId, actorId, version, status;
  final String? messageId;
  final Map? answer;
  final bool readOnly;
  final MessageSender? recipient;
  final ValueChanged<String>? onOpenMember;
  final Widget? trailing;
  final bool compact;
  final Future<void> Function(Map<String, Object?>) onSubmit;
  final Future<void> Function(String version, String data) onSave;
  @override
  State<QuestionBatchCard> createState() => _QuestionBatchCardState();
}

class _QuestionBatchCardState extends State<QuestionBatchCard> {
  late QuestionBatchController _controller;
  var _answered = Completer<void>();
  String? _savedDraft;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final pending = UserQuestion.activeCards[widget.messageId];
    final raw = widget.messageId == null
        ? null
        : InteractiveSelectionDrafts.instance.readOtherText(
            widget.messageId!,
            widget.actorId,
            widget.buttonId,
            widget.version,
          );
    final saved = raw == null || raw.isEmpty ? null : jsonDecode(raw) as Map;
    _controller = QuestionBatchController(
      QuestionBatch(widget.questions),
      index: pending?.questionIndex ?? saved?['index'] as int? ?? 0,
      answers: widget.answer != null
          ? {
              for (final value in widget.answer!['value'] as List)
                value['id'] as String: value,
            }
          : pending != null
          ? pending.answers
          : saved == null
          ? null
          : Map<String, Object?>.from(saved['answers'] as Map),
    );
    _controller.addListener(_save);
  }

  void _save() {
    if (!widget.readOnly && widget.messageId != null) {
      final pending = UserQuestion.activeCards[widget.messageId];
      if (pending != null) {
        pending.answers
          ..clear()
          ..addAll(_controller.answers);
        pending.questionIndex = _controller.index;
      }
      final data = jsonEncode({
        'index': _controller.index,
        'answers': _controller.answers,
      });
      if (data == _savedDraft) return;
      _savedDraft = data;
      widget.onSave(widget.version, data);
    }
  }

  @override
  void didUpdateWidget(QuestionBatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = UserQuestion.activeCards[widget.messageId];
    if (pending != null && widget.answer == null) {
      _controller.answers
        ..clear()
        ..addAll(pending.answers);
      _controller.index = pending.questionIndex;
    }
    if (widget.answer != oldWidget.answer ||
        widget.version != oldWidget.version) {
      if (widget.answer != null && !_answered.isCompleted) _answered.complete();
      _controller.batch = QuestionBatch(widget.questions);
      if (widget.answer != null) {
        _controller.answers
          ..clear()
          ..addAll({
            for (final value in widget.answer!['value'] as List)
              value['id'] as String: value,
          });
      } else if (widget.version != oldWidget.version) {
        _controller.answers.clear();
        _controller.index = 0;
        if (!_answered.isCompleted) _answered.complete();
        _answered = Completer<void>();
        _savedDraft = null;
      }
    }
  }

  @override
  void dispose() {
    if (!_answered.isCompleted) _answered.complete();
    _controller.removeListener(_save);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.compact
      ? QuestionSheetLayout(
          title: '问题',
          heading: const SizedBox.shrink(),
          child: _form(compact: false),
        )
      : widget.messageId == null
      ? _form()
      : QuestionCardAnchor(
          messageId: widget.messageId!,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: _form(),
          ),
        );

  Future<void> _open() async {
    final pending = UserQuestion.activeCards[widget.messageId];
    if (pending != null) {
      await showUserQuestionSheet(
        context,
        question: pending,
        showSender: false,
        onOpenSender: () => widget.onOpenMember?.call(pending.sender.id),
      );
      if (mounted)
        setState(() {
          _controller.answers
            ..clear()
            ..addAll(pending.answers);
          _controller.index = pending.questionIndex;
        });
      return;
    }
    await showQuestionSheet(
      context,
      messageId: widget.messageId,
      closeWhen: widget.readOnly ? null : _answered.future,
      child: QuestionSheetLayout(
        title: '问题',
        heading: const SizedBox.shrink(),
        child: _form(compact: false),
      ),
    );
  }

  Widget _form({bool compact = true}) => QuestionBatchForm(
    controller: _controller,
    compact: compact,
    readOnly: widget.readOnly,
    status: widget.status,
    recipient: widget.recipient,
    onOpenMember: widget.onOpenMember,
    trailing: widget.trailing,
    closeWhen: widget.readOnly ? null : _answered.future,
    onSubmit: () async {
      final controller = _controller;
      if (controller.sending) return;
      controller.setSending(true);
      try {
        await widget.onSubmit(Map.of(controller.answers));
      } finally {
        if (mounted && identical(controller, _controller))
          controller.setSending(false);
      }
    },
  );
}
