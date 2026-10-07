import 'package:characters/characters.dart';

/// Options and optional written answers are resolved for human and AI submissions.
class InteractiveSelection {
  InteractiveSelection(this.config);
  final Map<String, Object?> config;
  bool get multiple => config['mode'] == 'multiple';
  bool get showConfirm => config['showConfirm'] == true;
  bool get needsConfirmation => multiple || showConfirm;
  static const otherId = '__other__';
  bool get hasOther => config['other'] != null;
  int get otherMaxLength =>
      (config['other'] as Map?)?['maxLength'] as int? ?? 50;
  List<Map<String, Object?>> get options => [
    for (final option in config['options'] as List)
      Map<String, Object?>.from(option as Map),
    if (hasOther) {'id': otherId, 'label': '其他'},
  ];
  int get minimum => config['minSelections'] as int? ?? 1;
  int get maximum =>
      multiple ? config['maxSelections'] as int? ?? options.length : 1;

  void validate() {
    if (config['showConfirm'] != null && config['showConfirm'] is! bool) {
      throw ArgumentError('showConfirm 必须是布尔值');
    }
    if (hasOther &&
        (config['other'] is! Map ||
            (config['other'] as Map)['maxLength'] != null &&
                (config['other'] as Map)['maxLength'] is! int ||
            otherMaxLength < 1 ||
            otherMaxLength > 500)) {
      throw ArgumentError('其他选项字数上限须为 1–500，默认 50');
    }
    if (!['single', 'multiple'].contains(config['mode']) ||
        options.isEmpty ||
        (config['options'] as List).length > 25 ||
        minimum < 1 ||
        maximum < minimum ||
        maximum > options.length ||
        (!multiple &&
            (minimum != 1 ||
                config['maxSelections'] != null &&
                    config['maxSelections'] != 1))) {
      throw ArgumentError('请选择有效的单选或多选配置，选择数量须在选项数量范围内');
    }
    final ids = <String>{};
    for (final option in options) {
      if (option['id'] is! String ||
          (option['id'] as String).isEmpty ||
          !ids.add(option['id'] as String) ||
          option['label'] is! String ||
          (option['label'] as String).trim().isEmpty) {
        throw ArgumentError('选项标识须唯一，选项文字不能为空');
      }
    }
  }

  Map<String, Object?> resolve(Map<String, Object?> button, Object? input) {
    String? otherText;
    if (input is Map) {
      if (!hasOther || input['otherText'] is! String) {
        throw ArgumentError('这个选项不接受自填内容');
      }
      otherText = (input['otherText'] as String).trim();
      input = input['options'];
    }
    if (multiple ? input is! List : input is! String)
      throw ArgumentError(multiple ? '请提供所选选项标识数组' : '请提供所选选项标识');
    final ids = multiple ? List<Object?>.from(input as List) : [input];
    if (ids.length < minimum ||
        ids.length > maximum ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !options.any((option) => option['id'] == id))) {
      throw ArgumentError('请选择 $minimum–$maximum 个有效且不重复的选项');
    }
    if (hasOther && ids.contains(otherId)) {
      if (otherText == null ||
          otherText.isEmpty ||
          otherText.characters.length > otherMaxLength) {
        throw ArgumentError('请填写其他选项，最多 $otherMaxLength 字');
      }
    } else if (otherText != null) {
      throw ArgumentError('填写内容必须同时选择其他选项');
    }
    final selected = [
      for (final option in options)
        if (ids.contains(option['id']))
          {
            'buttonId': '${button['id']}/${option['id']}',
            'optionId': option['id'],
            'label': option['label'],
            if (hasOther && option['id'] == otherId) 'text': otherText,
            'value': hasOther && option['id'] == otherId
                ? otherText
                : option.containsKey('value')
                ? option['value']
                : option['id'],
          },
    ];
    return {
      ...button,
      'label': selected.map((option) => option['label']).join('、'),
      'value': multiple
          ? selected.map((option) => option['value']).toList()
          : selected.single['value'],
      'selections': selected,
    };
  }
}

Iterable<Map<String, Object?>> selectionEntries(Map<String, Object?> choice) =>
    choice['selections'] == null
    ? [choice]
    : (choice['selections'] as List).map(
        (item) => Map<String, Object?>.from(item as Map),
      );

List<Map<String, Object?>> interactionSummary(
  List<Map<String, Object?>> buttons,
  Iterable<Map<String, Object?>> choices,
) {
  final counts = <(String, String), Map<String, Object?>>{};
  void add(Map<String, Object?> option, num count) {
    final key = (option['buttonId'] as String, option['label'] as String);
    final entry = counts.putIfAbsent(
      key,
      () => {'buttonId': key.$1, 'label': key.$2, 'count': 0},
    );
    entry['count'] = (entry['count'] as num) + count;
  }

  for (final button in buttons) {
    if (button['selection'] case final Map config) {
      for (final option in InteractiveSelection(
        Map<String, Object?>.from(config),
      ).options) {
        add({
          'buttonId': '${button['id']}/${option['id']}',
          'label': option['label'],
        }, 0);
      }
    } else {
      add({'buttonId': button['id'], 'label': button['label']}, 0);
    }
  }
  for (final choice in choices) {
    for (final option in selectionEntries(choice)) {
      add(option, choice['weight'] as num? ?? 1);
    }
  }
  return counts.values.toList();
}
