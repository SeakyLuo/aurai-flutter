import 'package:flutter/material.dart';
import '../../agent/ask_user_tool.dart';
import '../../app/glass_notice.dart';
import 'settings_icon.dart';
import 'user_question_option_tile.dart';
import 'vote_selection_hint.dart';
import '../../domain/avatar_style.dart';
import 'profile_avatar.dart';

Color interactiveColor(BuildContext context, String name) {
  final colors = Theme.of(context).colorScheme;
  return switch (name) {
    'primary' => colors.primary,
    'onPrimary' => colors.onPrimary,
    'surface' => colors.surface,
    'onSurface' => colors.onSurface,
    'surfaceContainer' => colors.surfaceContainer,
    'onSurfaceVariant' => colors.onSurfaceVariant,
    'outline' => colors.outline,
    'error' => colors.error,
    _ => throw StateError('未注册主题颜色 $name'),
  };
}

Alignment interactiveAlignment(String name) => switch (name) {
  'topLeft' => Alignment.topLeft,
  'topCenter' => Alignment.topCenter,
  'topRight' => Alignment.topRight,
  'centerLeft' => Alignment.centerLeft,
  'center' => Alignment.center,
  'centerRight' => Alignment.centerRight,
  'bottomLeft' => Alignment.bottomLeft,
  'bottomCenter' => Alignment.bottomCenter,
  'bottomRight' => Alignment.bottomRight,
  _ => throw StateError('未注册对齐方式 $name'),
};

Widget buildInteractiveExtra(
  BuildContext context,
  Map<String, Object?> node, {
  required Widget Function(Map<String, Object?>) build,
  required Object? value,
  required bool enabled,
  required ValueChanged<Object?> onChanged,
}) {
  final key = node['key'] == null ? null : ValueKey(node['key']);
  Widget child() => build(Map<String, Object?>.from(node['child'] as Map));
  List<Widget> children() => [
    for (final item in node['children'] as List)
      build(Map<String, Object?>.from(item as Map)),
  ];
  double? number(String name) => (node[name] as num?)?.toDouble();
  switch (node['type']) {
    case 'ProfileAvatar':
      final color = interactiveColor(
        context,
        node['color'] as String? ?? 'surfaceContainer',
      );
      final encoded = color.toARGB32().toRadixString(16);
      return Semantics(
        key: key,
        image: true,
        label: node['semanticLabel'] as String? ?? node['name'] as String,
        child: Align(
          heightFactor: 1,
          child: ProfileAvatar(
            name: node['name'] as String,
            size: number('size') ?? 40,
            style: AvatarStyle(
              icon: node['icon'] as String? ?? 'initial',
              color: 'custom:$encoded:$encoded:0',
            ),
          ),
        ),
      );
    case 'Container':
      return Container(
        key: key,
        width: number('width'),
        height: number('height'),
        padding: node['padding'] == null
            ? null
            : EdgeInsets.all(number('padding')!),
        decoration: BoxDecoration(
          color: node['color'] == null
              ? null
              : interactiveColor(context, node['color'] as String),
          borderRadius: BorderRadius.circular(number('borderRadius') ?? 0),
        ),
        child: node['child'] == null ? null : child(),
      );
    case 'Align':
      return Align(
        key: key,
        alignment: interactiveAlignment(
          node['alignment'] as String? ?? 'center',
        ),
        heightFactor: 1,
        child: child(),
      );
    case 'Center':
      return Center(key: key, heightFactor: 1, child: child());
    case 'Wrap':
      return Wrap(
        key: key,
        spacing: number('spacing') ?? 0,
        runSpacing: number('runSpacing') ?? 0,
        alignment: WrapAlignment.values.byName(
          node['alignment'] as String? ?? 'start',
        ),
        children: children(),
      );
    case 'Stack':
      return Stack(
        key: key,
        alignment: interactiveAlignment(
          node['alignment'] as String? ?? 'topLeft',
        ),
        children: children(),
      );
    case 'Positioned':
      return Positioned(
        key: key,
        left: number('left'),
        top: number('top'),
        right: number('right'),
        bottom: number('bottom'),
        width: number('width'),
        height: number('height'),
        child: child(),
      );
    case 'ListView':
      return ListView(
        key: key,
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: children(),
      );
    case 'Divider':
      return Divider(
        key: key,
        height: number('height'),
        thickness: number('thickness'),
      );
    case 'Icon':
      return Semantics(
        key: key,
        label: node['semanticLabel'] as String?,
        child: SizedBox.square(
          dimension: number('size') ?? 24,
          child: SettingsIcon(
            type: SettingsIconType.values.byName(node['name'] as String),
            color: interactiveColor(
              context,
              node['color'] as String? ?? 'onSurfaceVariant',
            ),
          ),
        ),
      );
    case 'Image':
      return Image.network(
        node['src'] as String,
        key: key,
        width: number('width'),
        height: number('height'),
        fit: BoxFit.values.byName(node['fit'] as String? ?? 'contain'),
        semanticLabel: node['semanticLabel'] as String?,
        errorBuilder: (context, error, stack) => Center(
          child: IconButton(
            tooltip: '查看图片加载错误',
            icon: const SettingsIcon(type: SettingsIconType.info),
            onPressed: () => ScaffoldMessenger.of(context).showToast(
              SnackBar(content: Text(error.toString())),
              kind: ToastKind.error,
            ),
          ),
        ),
      );
    case 'SwitchListTile':
      return SwitchListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: build(Map<String, Object?>.from(node['title'] as Map)),
        value: value as bool,
        onChanged: enabled ? onChanged : null,
      );
    case 'CheckboxListTile':
      return UserQuestionOptionTile(
        key: key,
        option: UserQuestionOption(
          content: (node['title'] as Map)['data'] as String,
        ),
        number: 1,
        selected: value as bool,
        multiple: true,
        onTap: enabled ? () => onChanged(!value) : null,
      );
    case 'Slider':
      return SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
        child: Slider(
          key: key,
          value: (value as num).toDouble(),
          min: number('min') ?? 0,
          max: number('max') ?? 1,
          divisions: node['divisions'] as int?,
          label: value.toString(),
          onChanged: enabled ? onChanged : null,
        ),
      );
    case 'DropdownButton':
      return DropdownButton<String>(
        key: key,
        isExpanded: true,
        value: value as String?,
        hint: Text(node['hintText'] as String? ?? '请选择'),
        icon: const SettingsIcon(type: SettingsIconType.chevronDown),
        items: [
          if (node['required'] != true)
            const DropdownMenuItem<String>(value: null, child: Text('不选择')),
          for (final item in node['items'] as List)
            DropdownMenuItem(
              value: item['value'] as String,
              child: Text((item['child'] as Map)['data'] as String),
            ),
        ],
        onChanged: enabled ? onChanged : null,
      );
    case 'ChoiceGroup':
      final multiple = node['multiple'] == true;
      final selected = multiple
          ? (value as List).cast<String>()
          : [if (value != null) value as String];
      final items = node['items'] as List;
      final maximum = node['maxSelections'] as int? ?? items.length;
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (multiple)
            VoteSelectionHint(
              minimum:
                  (node['minSelections'] as int? ?? 0) == 0 &&
                      node['required'] == true
                  ? 1
                  : node['minSelections'] as int? ?? 0,
              maximum: maximum,
              selectedCount: selected.length,
            ),
          for (final (index, item) in items.indexed)
            UserQuestionOptionTile(
              key: ValueKey(item['value']),
              option: UserQuestionOption(
                content: (item['child'] as Map)['data'] as String,
              ),
              number: index + 1,
              multiple: multiple,
              vote: !multiple,
              selected: selected.contains(item['value']),
              onTap:
                  !enabled ||
                      (multiple &&
                          selected.length >= maximum &&
                          !selected.contains(item['value']))
                  ? null
                  : () {
                      final id = item['value'] as String;
                      if (!multiple) {
                        onChanged(
                          selected.contains(id) &&
                                  node['required'] != true &&
                                  (node['minSelections'] as int? ?? 0) == 0
                              ? null
                              : id,
                        );
                        return;
                      }
                      onChanged(
                        selected.contains(id)
                            ? selected.where((entry) => entry != id).toList()
                            : [...selected, id],
                      );
                    },
            ),
        ],
      );
    default:
      throw StateError('未注册组件 ${node['type']}');
  }
}
