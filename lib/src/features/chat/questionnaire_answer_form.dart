import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import '../../domain/interactive_message.dart';
import '../../domain/interactive_selection.dart';
import 'user_question_option_tile.dart';

/// Display a submitted questionnaire without editable controls or submit actions.
class QuestionnaireAnswerForm extends StatelessWidget {
  const QuestionnaireAnswerForm({
    super.key,
    required this.card,
    required this.answer,
  });

  final InteractiveMessage card;
  final Map answer;

  @override
  Widget build(BuildContext context) {
    final button = card.buttons.single;
    final answers =
        answer['answers'] ??
        (button['questions'] != null ? answer['value'] : null);
    final definitions = button['questions'] as List?;
    final fields = answers is List
        ? [
            for (final item in answers)
              {
                ...?definitions
                    ?.cast<Map>()
                    .where((question) => question['id'] == item['id'])
                    .firstOrNull,
                ...item as Map,
              },
          ]
        : [
            {
              'question': card.title,
              'answer': answer['label'],
              if (button['selection'] case final Map selection) ...{
                ...selection,
                'options': InteractiveSelection(
                  Map<String, Object?>.from(selection),
                ).options,
              },
              'selected': [
                for (final item in selectionEntries(
                  Map<String, Object?>.from(answer),
                ))
                  item['optionId'],
              ],
              'text': selectionEntries(Map<String, Object?>.from(answer))
                  .where((item) => item['text'] != null)
                  .map((item) => item['text'])
                  .join('、'),
            },
          ];
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.body.isNotEmpty) ...[
          Text(
            card.body,
            style: TextStyle(fontSize: 14, height: 1.5, color: secondary),
          ),
        ],
        for (final (index, field) in fields.indexed) ...[
          if (index > 0 || card.body.isNotEmpty) const SizedBox(height: 20),
          if (answers is List || field['question'] != card.title)
            Text(
              field['question'] as String,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          if ((field['description'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field['description'] as String,
              style: TextStyle(color: secondary),
            ),
          ],
          if (field['skipped'] != true)
            for (final (index, option)
                in (field['options'] as List? ?? const []).indexed) ...[
              const SizedBox(height: 8),
              UserQuestionOptionTile(
                option: UserQuestionOption.fromSelection(option as Map),
                number: index + 1,
                selected: (field['selected'] as List).contains(option['id']),
                multiple: field['mode'] == 'multiple',
                vote: true,
                optionPrefix: field['optionPrefix'] as String?,
                onTap: null,
              ),
            ],
          if (field['skipped'] == true ||
              (field['options'] as List? ?? const []).isEmpty ||
              (field['text'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ((field['text'] as String? ?? '').isNotEmpty
                      ? field['text']
                      : field['answer'])
                  as String,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ],
        if (answer['reason'] case final String reason) ...[
          const SizedBox(height: 20),
          Text('提交理由', style: TextStyle(fontSize: 13, color: secondary)),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ],
    );
  }
}
