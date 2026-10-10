import 'interactive_message.dart';

String questionnaireHiddenAnswersText(InteractiveMessage card, String viewer) {
  final allowed = card.participation['visibilityActors'] as List?;
  final excluded = card.participation['visibilityExcludedActors'] as List?;
  final canReadAfterCompletion =
      card.snapshotView == null &&
      !card.completed &&
      (card.participation['visibility'] ?? 'private') != 'private' &&
      (allowed == null || allowed.contains(viewer)) &&
      !(excluded?.contains(viewer) ?? false);
  return canReadAfterCompletion ? '问卷收集完成后公布结果' : '其他人的回答不公开';
}

/// A questionnaire stores either one selection or an atomic group of answers.
String questionnaireAnswerText(Map choice) {
  if (choice['answers'] case final List answers) {
    return answers
        .map((answer) => '${answer['question']}：${answer['answer']}')
        .join('\n');
  }
  final value = choice['value'];
  if (value is List &&
      value.isNotEmpty &&
      value.first is Map &&
      (value.first as Map).containsKey('question')) {
    return value
        .map((answer) => '${answer['question']}：${answer['answer']}')
        .join('\n');
  }
  return choice['label'] as String;
}
