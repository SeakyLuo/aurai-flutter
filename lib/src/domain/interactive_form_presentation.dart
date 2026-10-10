import 'interactive_content.dart';

String interactiveFieldLabel(Map<String, Object?> field, int index) =>
    (field['label'] ??
            (field['title'] as Map?)?['data'] ??
            field['hintText'] ??
            '第 ${index + 1} 项')
        as String;

/// Capture labels with every form submission; result rendering does not depend
/// on whether the author calls this form a question, poll or questionnaire.
/// Capture display text at submission, so editing a question later cannot
/// change the meaning of an existing answer or expose internal option values.
List<Map<String, Object?>> interactiveFormAnswers(
  InteractiveContent tree,
  Map<String, Object?> values,
) => [
  for (final (index, field)
      in tree.nodes
          .where((node) => interactiveFieldTypes.contains(node['type']))
          .indexed)
    {
      'question': interactiveFieldLabel(field, index),
      'answer': interactiveFieldText(field, values[field['key']]),
    },
];

String interactiveFieldText(Map<String, Object?> field, Object? value) {
  if (field['items'] case final List items) {
    final selected = value is List ? value : [value];
    final labels = items
        .where((item) => selected.contains(item['value']))
        .map((item) => (item['child'] as Map)['data'] as String)
        .toList();
    return labels.isEmpty ? '未填写' : labels.join('、');
  }
  if (value is bool) return value ? '是' : '否';
  if (value is String) return value.trim().isEmpty ? '未填写' : value;
  return value.toString();
}

/// Call only when aggregate visibility permits it. Individual values never
/// appear in this projection; weighted counts use the existing host weights.
List<Map<String, Object?>> interactiveFormMetrics(
  InteractiveContent tree,
  Iterable<Map<String, Object?>> submissions,
) {
  final entries = submissions.toList();
  final total = entries.fold<num>(
    0,
    (sum, entry) => sum + (entry['weight'] as num? ?? 1),
  );
  return [
    for (final (index, field)
        in tree.nodes
            .where((node) => interactiveFieldTypes.contains(node['type']))
            .indexed)
      if (field['items'] case final List items)
        {
          'label': interactiveFieldLabel(field, index),
          'options': [
            for (final item in items)
              _optionMetric(
                field['key'] as String,
                item as Map,
                entries,
                total,
              ),
          ],
        },
  ];
}

Map<String, Object?> _optionMetric(
  String field,
  Map item,
  List<Map<String, Object?>> entries,
  num total,
) {
  final count = entries.fold<num>(0, (sum, entry) {
    final value = (entry['value'] as Map?)?[field];
    final selected = value is List
        ? value.contains(item['value'])
        : value == item['value'];
    return sum + (selected ? entry['weight'] as num? ?? 1 : 0);
  });
  return {
    'label': (item['child'] as Map)['data'],
    'count': count,
    'fraction': total == 0 ? 0.0 : count / total,
  };
}
