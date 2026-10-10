import 'package:characters/characters.dart';

const interactiveFieldTypes = {
  'TextField',
  'SwitchListTile',
  'CheckboxListTile',
  'Slider',
  'DropdownButton',
  'ChoiceGroup',
};

Object? interactiveInitialValue(Map<String, Object?> field) =>
    field.containsKey('initialValue')
    ? field['initialValue']
    : switch (field['type']) {
        'TextField' => '',
        'SwitchListTile' || 'CheckboxListTile' => false,
        'Slider' => field['min'] ?? 0,
        'ChoiceGroup' when field['multiple'] == true => <String>[],
        _ => null,
      };

/// Validation is shared by human form submission and the AI action tool.
void validateInteractiveFieldValue(
  Map<String, Object?> field,
  Object? value, {
  bool submitting = true,
}) {
  final error = interactiveFieldValueError(
    field,
    value,
    submitting: submitting,
  );
  if (error != null) throw ArgumentError(error);
}

String? interactiveFieldValueError(
  Map<String, Object?> field,
  Object? value, {
  bool submitting = true,
}) {
  final label =
      field['label'] ??
      (field['title'] as Map?)?['data'] ??
      field['hintText'] ??
      '内容';
  switch (field['type']) {
    case 'TextField':
      if (value is! String ||
          value.characters.length > (field['maxLength'] as int? ?? 2000)) {
        return '$label 必须为长度范围内的文本';
      }
      if (submitting && field['required'] == true && value.trim().isEmpty)
        return '请填写$label';
    case 'SwitchListTile':
    case 'CheckboxListTile':
      if (value is! bool) return '$label 必须为布尔值';
      if (submitting && field['required'] == true && value != true)
        return '请确认$label';
    case 'Slider':
      final min = field['min'] as num? ?? 0;
      final max = field['max'] as num? ?? 1;
      if (value is! num || !value.isFinite || value < min || value > max)
        return '滑块值必须在 $min–$max 之间';
      if (field['divisions'] case final int divisions) {
        final step = (value - min) / (max - min) * divisions;
        if ((step - step.round()).abs() > 0.000001)
          return '滑块值必须符合 divisions 刻度';
      }
    case 'DropdownButton':
    case 'ChoiceGroup':
      final allowed = {
        for (final item in field['items'] as List) item['value'],
      };
      final multiple =
          field['type'] == 'ChoiceGroup' && field['multiple'] == true;
      final selected = multiple
          ? value
          : value == null
          ? <Object?>[]
          : [value];
      if (selected is! List ||
          selected.toSet().length != selected.length ||
          selected.any((item) => !allowed.contains(item)))
        return '请选择组件定义中的选项';
      if (submitting && field['required'] == true && selected.isEmpty)
        return '请选择$label';
      if (submitting && selected.length < (field['minSelections'] as int? ?? 0))
        return '至少选择 ${field['minSelections']} 项';
      if (selected.length > (field['maxSelections'] as int? ?? allowed.length))
        return '最多选择 ${field['maxSelections']} 项';
  }
  return null;
}

void validateInteractiveField(Map<String, Object?> field) {
  if (field.containsKey('label') &&
      (field['label'] is! String ||
          (field['label'] as String).trim().isEmpty ||
          (field['label'] as String).length > 600)) {
    throw ArgumentError('字段 label 需要 1–600 字的题目');
  }
  if (field['key'] is! String || (field['key'] as String).isEmpty)
    throw ArgumentError('表单组件需要稳定的 key');
  if (field['required'] != null && field['required'] is! bool)
    throw ArgumentError('required 必须为布尔值');
  if (field['type'] == 'Slider') {
    final min = field['min'] ?? 0;
    final max = field['max'] ?? 1;
    if (min is! num ||
        max is! num ||
        !min.isFinite ||
        !max.isFinite ||
        !(max - min).isFinite ||
        max <= min)
      throw ArgumentError('Slider 需要有限且递增的 min/max');
    final divisions = field['divisions'];
    if (divisions != null &&
        (divisions is! int || divisions < 1 || divisions > 1000))
      throw ArgumentError('divisions 必须为 1–1000 的整数');
  }
  if (['DropdownButton', 'ChoiceGroup'].contains(field['type'])) {
    final items = field['items'];
    if (items is! List || items.isEmpty || items.length > 100)
      throw ArgumentError('选项数量需要在 1–100 之间');
    final values = <String>{};
    for (final item in items) {
      if (item is! Map ||
          item['value'] is! String ||
          !values.add(item['value'] as String) ||
          (item['value'] as String).isEmpty ||
          (item['child'] as Map?)?['type'] != 'Text' ||
          (item['child'] as Map?)?['data'] is! String ||
          ((item['child'] as Map)['data'] as String).trim().isEmpty ||
          ((item['child'] as Map)['data'] as String).length > 10000)
        throw ArgumentError('每个选项需要唯一 value 和非空 Text child');
    }
    if (field['multiple'] != null && field['multiple'] is! bool)
      throw ArgumentError('multiple 必须为布尔值');
    final min = field['minSelections'] ?? 0;
    final max =
        field['maxSelections'] ??
        (field['multiple'] == true ? items.length : 1);
    if (min is! int ||
        max is! int ||
        min < 0 ||
        max < 1 ||
        min > max ||
        max > items.length ||
        (field['multiple'] != true && max != 1))
      throw ArgumentError('选择数量范围无效');
  }
  if (['SwitchListTile', 'CheckboxListTile'].contains(field['type']) &&
      ((field['title'] as Map?)?['type'] != 'Text' ||
          (field['title'] as Map?)?['data'] is! String ||
          ((field['title'] as Map)['data'] as String).trim().isEmpty))
    throw ArgumentError('开关和勾选项需要 Text title');
  validateInteractiveFieldValue(
    field,
    interactiveInitialValue(field),
    submitting: false,
  );
}
