import 'dart:convert';

/// GLM text variants are distinct from the GLM-*V vision models.
/// https://docs.bigmodel.cn/cn/guide/models/text/glm-4.6
/// GLM-5.2 also explicitly rejected image parts with code 1210 on this device.
bool modelSupportsImageInput(String model) => !const {
  'glm-4.6',
  'glm-5.1',
  'glm-5.2',
  'glm-5.3-flash',
  'zhipu/glm-4.6',
  'zhipu/glm-5.1',
  'zhipu/glm-5.2',
  'zhipu/glm-5.3-flash',
}.contains(model.toLowerCase());

Map<String, Object?> imagePlaceholder({String? name}) => {
  'type': 'input_text',
  'text': jsonEncode({
    'type': 'image',
    if (name != null) 'name': name,
    'contentProvided': false,
    'reason': 'model_does_not_support_images',
  }),
};

/// Process protocol content parts, never text or JSON inside a tool result.
List<Map<String, Object?>> textOnlyModelInput(
  List<Map<String, Object?>> input,
) => [
  for (final item in input)
    if (item['content'] is List)
      {...item, 'content': _textOnlyParts(item['content'] as List)}
    else if (item['type'] == 'function_call_output' && item['output'] is List)
      {...item, 'output': _textOnlyParts(item['output'] as List)}
    else
      item,
];

List<Object?> _textOnlyParts(List parts) => [
  for (final part in parts)
    if ((part as Map)['type'] == 'input_image') imagePlaceholder() else part,
];
