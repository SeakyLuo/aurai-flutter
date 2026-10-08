/// Rich options reference existing messages so media and miniapp state keep
/// their original storage and access rules instead of becoming detached copies.
Map<String, Object?> selectionOption(Map raw, int index) => {
  ...raw.cast<String, Object?>(),
  'label': (raw['label'] as String?)?.trim().isNotEmpty == true
      ? raw['label']
      : '选项 ${index + 1}',
};

void validateSelectionOption(Map option) {
  final content = option['content'];
  if (content != null &&
      (content is! Map ||
          content.length != 1 ||
          content['messageId'] is! String ||
          (content['messageId'] as String).trim().isEmpty)) {
    throw ArgumentError('选项内容须引用有效的 messageId');
  }
  final label = option['label'];
  if (label != null && label is! String ||
      content == null && (label is! String || label.trim().isEmpty)) {
    throw ArgumentError('文字选项须填写文字，媒体选项须提供内容引用');
  }
}

bool hasRichOptions(Iterable options) =>
    options.any((option) => (option as Map)['content'] != null);
