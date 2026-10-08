import 'package:characters/characters.dart';
import 'selection_option.dart';

/// One native question group is submitted atomically as one participant value.
class QuestionBatch {
  QuestionBatch(List raw)
    : questions = raw
          .map((value) => Map<String, Object?>.from(value as Map))
          .toList() {
    validate();
  }

  final List<Map<String, Object?>> questions;

  void validate() {
    if (questions.isEmpty || questions.length > 10) {
      throw ArgumentError('每组问题需要 1–10 题');
    }
    final ids = <String>{};
    for (final question in questions) {
      final id = question['id'];
      final title = question['question'];
      final options = question['options'];
      if (id is! String ||
          id.isEmpty ||
          !ids.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 600 ||
          options is! List ||
          options.length > 25 ||
          !['single', 'multiple', 'text'].contains(question['mode'])) {
        throw ArgumentError('问题需要唯一标识、1–600 字题目和有效的回答类型');
      }
      if (question['mode'] == 'text' ? options.isNotEmpty : options.isEmpty) {
        throw ArgumentError('文字题不提供选项，选择题至少提供一个选项');
      }
      final optionIds = <String>{};
      for (final option in options) {
        if (option is Map) validateSelectionOption(option);
        if (option is! Map ||
            option['id'] is! String ||
            (option['id'] as String).isEmpty ||
            !optionIds.add(option['id'] as String)) {
          throw ArgumentError('选项标识须唯一，选项文字不能为空');
        }
      }
      question['options'] = [
        for (final (index, option) in options.indexed)
          selectionOption(option as Map, index),
      ];
      if (question['required'] != null && question['required'] is! bool ||
          question['showConfirm'] != null && question['showConfirm'] is! bool ||
          question['allowCustomAnswer'] != null &&
              question['allowCustomAnswer'] is! bool) {
        throw ArgumentError('required、allowCustomAnswer 和 showConfirm 必须是布尔值');
      }
    }
  }

  bool accepts(Map<String, Object?> question, Map answer) {
    final selected = answer['selected'] as List? ?? const [];
    final text = (answer['text'] as String? ?? '').trim();
    if (answer['skipped'] == true) {
      return question['required'] == false && selected.isEmpty && text.isEmpty;
    }
    if (text.isNotEmpty) {
      return selected.isEmpty &&
          text.characters.length <= 2000 &&
          (question['mode'] == 'text' || question['allowCustomAnswer'] == true);
    }
    final options = question['options'] as List;
    return question['mode'] != 'text' &&
        selected.isNotEmpty &&
        (question['mode'] == 'multiple' || selected.length == 1) &&
        selected.toSet().length == selected.length &&
        selected.every((id) => options.any((option) => option['id'] == id));
  }

  List<Map<String, Object?>> resolve(Object? input) {
    if (input is Map && input['skipQuestions'] == true && input.length == 1) {
      return [
        for (final question in questions) _answer(question, {'skipped': true}),
      ];
    }
    if (input is! Map ||
        input.length != questions.length ||
        questions.any(
          (q) => input[q['id']] is! Map || !accepts(q, input[q['id']] as Map),
        )) {
      throw ArgumentError('请完成必答题；每题选择有效选项或填写不超过 2000 字的回答');
    }
    return [
      for (final question in questions)
        _answer(question, input[question['id']] as Map),
    ];
  }

  Map<String, Object?> _answer(Map<String, Object?> question, Map answer) {
    final selected = (answer['selected'] as List? ?? const []).cast<String>();
    final text = (answer['text'] as String? ?? '').trim();
    return {
      'id': question['id'],
      'question': question['question'],
      'selected': selected,
      'text': text,
      'skipped': answer['skipped'] == true,
      'answer': answer['skipped'] == true
          ? '已跳过'
          : text.isNotEmpty
          ? text
          : (question['options'] as List)
                .where((o) => selected.contains(o['id']))
                .map((o) => o['label'])
                .join('、'),
    };
  }
}
