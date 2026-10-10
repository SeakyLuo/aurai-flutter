import 'avatar_portraits.dart';

const interactiveExtraProperties = <String, Set<String>>{
  'Container': {'child', 'width', 'height', 'padding', 'color', 'borderRadius'},
  'Align': {'child', 'alignment'},
  'Center': {'child'},
  'Wrap': {'children', 'spacing', 'runSpacing', 'alignment'},
  'Stack': {'children', 'alignment'},
  'Positioned': {'child', 'left', 'top', 'right', 'bottom', 'width', 'height'},
  'ListView': {'children'},
  'Divider': {'height', 'thickness'},
  'Image': {'src', 'width', 'height', 'fit', 'semanticLabel'},
  'Icon': {'name', 'size', 'color', 'semanticLabel'},
  'ProfileAvatar': {'name', 'icon', 'size', 'color', 'semanticLabel'},
  'SwitchListTile': {'title', 'initialValue', 'required'},
  'CheckboxListTile': {'title', 'initialValue', 'required'},
  'Slider': {'initialValue', 'min', 'max', 'divisions'},
  'DropdownButton': {'initialValue', 'items', 'hintText', 'required'},
  'ChoiceGroup': {
    'initialValue',
    'items',
    'multiple',
    'minSelections',
    'maxSelections',
    'required',
  },
};
const interactiveAlignments = [
  'topLeft',
  'topCenter',
  'topRight',
  'centerLeft',
  'center',
  'centerRight',
  'bottomLeft',
  'bottomCenter',
  'bottomRight',
];
const interactiveThemeColors = [
  'primary',
  'onPrimary',
  'surface',
  'onSurface',
  'surfaceContainer',
  'onSurfaceVariant',
  'outline',
  'error',
];
const interactiveIconNames = [
  'home',
  'star',
  'add',
  'remove',
  'info',
  'check',
  'play',
  'sound',
  'eye',
  'grid',
  'list',
  'tools',
  'data',
  'contacts',
  'notifications',
  'memory',
];

void validateInteractiveExtra(Map<String, Object?> node, String? parent) {
  final type = node['type'];
  if (type == 'ProfileAvatar') {
    final name = node['name'];
    if (name is! Map &&
        (name is! String || name.trim().isEmpty || name.length > 100)) {
      throw ArgumentError('ProfileAvatar.name 需要 1–100 字的名称');
    }
    final icon = node['icon'] ?? 'initial';
    if (icon != 'initial' &&
        icon != 'app_logo_white' &&
        !avatarPortraits.containsKey(icon)) {
      throw ArgumentError(
        'ProfileAvatar.icon 使用 initial、app_logo_white 或已登记插画头像',
      );
    }
    final size = node['size'] ?? 40;
    if (size is! num || !size.isFinite || size < 16 || size > 160) {
      throw ArgumentError('头像尺寸必须在 16–160 之间');
    }
  }
  for (final name in [
    'runSpacing',
    'borderRadius',
    'size',
    'thickness',
    'left',
    'top',
    'right',
    'bottom',
  ]) {
    final value = node[name];
    if (value != null &&
        (value is! num || !value.isFinite || value < 0 || value > 1000))
      throw ArgumentError('$name 必须为 0–1000 的有限数值');
  }
  if (node['color'] != null && !interactiveThemeColors.contains(node['color']))
    throw ArgumentError('color 使用主题颜色名称');
  if (node['alignment'] != null &&
      !(type == 'Wrap'
              ? [
                  'start',
                  'end',
                  'center',
                  'spaceBetween',
                  'spaceAround',
                  'spaceEvenly',
                ]
              : interactiveAlignments)
          .contains(node['alignment']))
    throw ArgumentError('不支持的 alignment');
  if (['Align', 'Center', 'Positioned'].contains(type) && node['child'] is! Map)
    throw ArgumentError('$type 需要 child');
  if (['Wrap', 'Stack', 'ListView'].contains(type) && node['children'] is! List)
    throw ArgumentError('$type 需要 children');
  if (type == 'Stack' &&
      !(node['children'] as List).any((child) => child['type'] != 'Positioned'))
    throw ArgumentError('Stack 需要至少一个非 Positioned 子组件确定尺寸');
  if (type == 'Positioned') {
    if (parent != 'Stack') throw ArgumentError('Positioned 必须直接位于 Stack');
    if (['left', 'right', 'width'].every(node.containsKey) ||
        ['top', 'bottom', 'height'].every(node.containsKey))
      throw ArgumentError('Positioned 同一方向不能同时设置两端和尺寸');
  }
  if (type == 'Image') {
    final src = node['src'];
    final uri = src is String ? Uri.tryParse(src) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty)
      throw ArgumentError('Image.src 使用完整 HTTPS 地址');
    if (node['fit'] != null &&
        ![
          'contain',
          'cover',
          'fill',
          'fitWidth',
          'fitHeight',
          'none',
          'scaleDown',
        ].contains(node['fit']))
      throw ArgumentError('不支持的图片 fit');
  }
  if (type == 'Icon' && !interactiveIconNames.contains(node['name']))
    throw ArgumentError('不支持的项目图标');
  if (node['semanticLabel'] != null && node['semanticLabel'] is! String)
    throw ArgumentError('semanticLabel 必须为文本');
}
