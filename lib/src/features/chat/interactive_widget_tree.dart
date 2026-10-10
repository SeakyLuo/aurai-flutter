import 'interactive_extra_widgets.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/interactive_message.dart';
import '../../storage/interactive_selection_drafts.dart';
import 'interactive_message_button.dart';
import 'message_composer.dart';
import 'interactive_dsl_sheet.dart';
import '../../domain/interactive_bindings.dart';
import '../../app/glass_notice.dart';

/// General Flutter-shaped content. InteractionCard uses the existing compound
/// card renderer; both consume InteractiveMessage.content and the same actions.
class InteractiveWidgetTree extends StatefulWidget {
  const InteractiveWidgetTree({
    super.key,
    required this.card,
    required this.actorId,
    required this.participantRevision,
    required this.onClick,
    required this.onSave,
    required this.readOnly,
    required this.host,
    this.messageId,
    this.value,
    this.busy,
    this.pendingButtonId,
  });
  final InteractiveMessage card;
  final String actorId;
  final String? messageId, busy, pendingButtonId;
  final int participantRevision;
  final Object? value;
  final bool readOnly;
  final Map<String, Object?> host;
  final Future<void> Function(Map<String, Object?> button, {Object? value})
  onClick;
  final Future<void> Function(String version, String data) onSave;

  @override
  State<InteractiveWidgetTree> createState() => _InteractiveWidgetTreeState();
}

class _InteractiveWidgetTreeState extends State<InteractiveWidgetTree> {
  final _sheet = InteractiveDslSheetController();
  late Map<String, Object?> _values;
  late String _version;
  late Map<String, Object?> _local;
  late Map<String, Object?> _context;
  var _rendered = 0;
  String? _lastRenderError;
  String _formVersion() {
    final fields =
        widget.card.widgetTree.nodes
            .where((node) => interactiveFieldTypes.contains(node['type']))
            .toList()
          ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
    return jsonEncode([
      if (widget.card.shared) widget.card.engine.round,
      for (final field in fields)
        {
          for (final key in [
            'key',
            'type',
            'initialValue',
            'min',
            'max',
            'divisions',
            'multiple',
            'maxSelections',
          ])
            if (field.containsKey(key)) key: field[key],
          if (field['items'] case final List items)
            'items': [for (final item in items) item['value']],
        },
    ]);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _resetLocal();
  }

  void _resetLocal() => _local = Map<String, Object?>.from(
    widget.card.widgetTree.json['state'] as Map? ?? const {},
  );

  void _load() {
    _version = _formVersion();
    final saved = widget.messageId == null || widget.readOnly
        ? null
        : InteractiveSelectionDrafts.instance.readOtherText(
            widget.messageId!,
            widget.actorId,
            '@form',
            _version,
          );
    final source = saved == null ? widget.value : jsonDecode(saved);
    _values = {
      for (final field in widget.card.widgetTree.nodes.where(
        (node) => interactiveFieldTypes.contains(node['type']),
      ))
        field['key'] as String:
            source is Map &&
                source.containsKey(field['key']) &&
                interactiveFieldValueError(
                      field,
                      source[field['key']],
                      submitting: false,
                    ) ==
                    null
            ? source[field['key']]
            : interactiveInitialValue(field),
    };
  }

  @override
  void didUpdateWidget(InteractiveWidgetTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_version != _formVersion() ||
        widget.readOnly != oldWidget.readOnly ||
        widget.participantRevision != oldWidget.participantRevision)
      _load();
    if (widget.participantRevision != oldWidget.participantRevision ||
        jsonEncode(widget.card.widgetTree.json['state']) !=
            jsonEncode(oldWidget.card.widgetTree.json['state'])) {
      _resetLocal();
    }
    final changed =
        widget.messageId != oldWidget.messageId ||
        widget.actorId != oldWidget.actorId ||
        widget.participantRevision != oldWidget.participantRevision ||
        jsonEncode(widget.card.content) != jsonEncode(oldWidget.card.content);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (changed) _sheet.close();
      _sheet.refresh();
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _changed(String key, Object? value) {
    setState(() => _values[key] = value);
    _sheet.refresh();
    if (widget.messageId != null) widget.onSave(_version, jsonEncode(_values));
  }

  String _formatted(String key) {
    final field = widget.card.widgetTree.nodes.firstWhere(
      (node) => node['key'] == key,
    );
    final value = _values[key];
    if (field['items'] case final List items) {
      final selected = value is List ? value : [value];
      return items
          .where((item) => selected.contains(item['value']))
          .map((item) => (item['child'] as Map)['data'] as String)
          .join('、');
    }
    return value is bool ? (value ? '是' : '否') : value?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) => _render(widget.card.widgetTree.json);

  Map<String, Object?> _bindingContext() => {
    'form': _values,
    'display': {for (final key in _values.keys) key: _formatted(key)},
    'local': _local,
    'host': {
      ...widget.host,
      'canSubmit': !widget.readOnly && widget.host['canSubmit'] == true,
      'canEdit': !widget.readOnly && widget.host['canEdit'] == true,
      'busy': widget.busy != null,
    },
  };

  /// Generated presentation failures are reported once at this UI boundary.
  Widget _render(Map<String, Object?> node) {
    try {
      _rendered = 0;
      _context = _bindingContext();
      final result = _build(node);
      _lastRenderError = null;
      return result;
    } on Object catch (error) {
      if (_lastRenderError != error.toString()) {
        _lastRenderError = error.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showError(error);
        });
      }
      return const SizedBox.shrink();
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showToast(SnackBar(content: Text(error.toString())), kind: ToastKind.error);

  Future<void> _runLocal(Map event) async {
    try {
      if (event['setState'] case final Map changes) {
        final fields = widget.card.widgetTree.nodes.where(
          (node) => interactiveFieldTypes.contains(node['type']),
        );
        for (final field in fields) {
          if ((event['validateFields'] as List? ?? const []).contains(
            field['key'],
          )) {
            validateInteractiveFieldValue(field, _values[field['key']]);
          }
        }
        final values = <String, Object?>{};
        final current = _bindingContext();
        for (final entry in changes.entries) {
          final value = resolveInteractiveBinding(entry.value, current);
          final previous = _local[entry.key];
          if (!(previous is bool && value is bool ||
              previous is String && value is String ||
              previous is num && value is num && value.isFinite)) {
            throw ArgumentError('setState 不能改变已声明状态的类型');
          }
          values[entry.key as String] = value;
        }
        setState(() => _local = {..._local, ...values});
        _sheet.refresh();
      } else if (event['showBottomSheet'] case final Map sheet) {
        await _sheet.show(
          context,
          title: sheet['title'] as String,
          resizeToAvoidBottomInset:
              sheet['resizeToAvoidBottomInset'] as bool? ?? false,
          buildContent: () =>
              _render(Map<String, Object?>.from(sheet['child'] as Map)),
        );
      } else {
        _sheet.close();
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    }
  }

  Widget _build(
    Map<String, Object?> node, [
    Map<String, Object?> scope = const {},
  ]) {
    if (++_rendered > 640) throw ArgumentError('展开后的界面最多 640 个节点，请分页展示');
    Object? evaluate(Object? value) =>
        resolveInteractiveBinding(value, {..._context, ...scope});
    bool flag(Object? value) {
      final result = evaluate(value);
      if (result is! bool) throw ArgumentError('visible/enabled 必须得到布尔值');
      return result;
    }

    final type = node['type'] as String;
    if (node['label'] case final String label
        when interactiveFieldTypes.contains(type)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(label),
          _build(Map<String, Object?>.of(node)..remove('label'), scope),
        ],
      );
    }
    final key = node['key'] == null ? null : ValueKey(node['key']);
    Widget child() =>
        _build(Map<String, Object?>.from(node['child'] as Map), scope);
    List<Widget> children() => [
      for (final raw in node['children'] as List)
        _build(Map<String, Object?>.from(raw as Map), scope),
    ];
    final enabled = flag(node['enabled'] ?? true);
    final locked = widget.readOnly || widget.busy != null || !enabled;
    final submitted = widget.host['submitted'] == true;
    final canSubmit = widget.host['canSubmit'] == true;
    switch (type) {
      case 'Visibility':
        return flag(node['visible']) ? child() : const SizedBox.shrink();
      case 'ForEach':
        final items = evaluate(node['items']);
        final offset = evaluate(node['offset'] ?? 0);
        if (items is! List || offset is! int || offset < 0) {
          throw ArgumentError('ForEach.items 需要列表，offset 需要非负整数');
        }
        return Column(
          key: key,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item)
                in items.skip(offset).take(node['limit'] as int? ?? 20).indexed)
              KeyedSubtree(
                key: ValueKey(index + offset),
                child: _build(
                  Map<String, Object?>.from(node['template'] as Map),
                  {...scope, 'item': item, 'index': index + offset},
                ),
              ),
          ],
        );
      case 'LinearProgressIndicator':
        final value = evaluate(node['value']);
        if (value is! num || !value.isFinite || value < 0 || value > 1) {
          throw ArgumentError('进度绑定必须得到 0–1 的有限数值');
        }
        return LinearProgressIndicator(key: key, value: value.toDouble());
      case 'Column':
        return Column(
          key: key,
          mainAxisSize: MainAxisSize.min,
          spacing: (node['spacing'] as num? ?? 0).toDouble(),
          mainAxisAlignment: MainAxisAlignment.values.byName(
            node['mainAxisAlignment'] as String? ?? 'start',
          ),
          crossAxisAlignment: CrossAxisAlignment.values.byName(
            node['crossAxisAlignment'] as String? ?? 'stretch',
          ),
          children: children(),
        );
      case 'Row':
        return Row(
          key: key,
          spacing: (node['spacing'] as num? ?? 0).toDouble(),
          mainAxisAlignment: MainAxisAlignment.values.byName(
            node['mainAxisAlignment'] as String? ?? 'start',
          ),
          crossAxisAlignment: CrossAxisAlignment.values.byName(
            node['crossAxisAlignment'] as String? ?? 'center',
          ),
          children: children(),
        );
      case 'Expanded':
        return Expanded(
          key: key,
          flex: node['flex'] as int? ?? 1,
          child: child(),
        );
      case 'Padding':
        return Padding(
          key: key,
          padding: EdgeInsets.all((node['padding'] as num).toDouble()),
          child: child(),
        );
      case 'SizedBox':
        return SizedBox(
          key: key,
          width: (node['width'] as num?)?.toDouble(),
          height: (node['height'] as num?)?.toDouble(),
          child: node['child'] == null ? null : child(),
        );
      case 'Text':
        final theme = Theme.of(context).textTheme;
        final data = node['data'];
        return Text(
          data is String
              ? data
              : data is Map &&
                    data.length == 1 &&
                    (data['ref'] as String? ?? '').startsWith('form.')
              ? _formatted((data['ref'] as String).substring(5))
              : (evaluate(data)?.toString() ?? ''),
          key: key,
          style: switch (node['style']) {
            'titleMedium' => theme.titleMedium,
            'labelSmall' => theme.labelSmall,
            _ => theme.bodyMedium,
          },
        );
      case 'TextField':
        return _InteractiveTextField(
          key: key,
          value: _values[node['key']] as String,
          enabled: !locked && canSubmit,
          hintText: node['hintText'] as String? ?? '',
          maxLength: node['maxLength'] as int? ?? 2000,
          onChanged: (value) => _changed(node['key'] as String, value),
        );
      case 'FilledButton':
      case 'TextButton':
      case 'InteractiveButton':
        final event = node['onPressed'] as Map;
        if (!InteractiveContent.isMessageButton(node)) {
          void activate() {
            _runLocal(event);
          }

          final label = (node['child'] as Map)['data'] as String;
          if (type == 'TextButton') {
            return TextButton(
              key: key,
              onPressed: enabled ? activate : null,
              child: Text(label),
            );
          }
          return InteractiveMessageButton(
            key: key,
            button: {'label': label, 'style': 'primary'},
            busy: false,
            locked: !enabled,
            onPressed: activate,
          );
        }
        final button = InteractiveContent.action(node);
        final disabled =
            locked ||
            button['disabled'] == true ||
            widget.pendingButtonId == button['id'] ||
            (button['action'] == 'submit' && !canSubmit) ||
            (button['action'] == 'nextRound' &&
                widget.card.shared &&
                widget.card.engine.phase == 'collecting');
        final shown = button['action'] == 'submit' && submitted && !canSubmit
            ? {...button, 'label': button['completedLabel'] ?? '已提交'}
            : button;
        void activate() => widget.onClick(
          button,
          value: button['input'] == 'json'
              ? Map<String, Object?>.of(_values)
              : null,
        );
        if (type == 'TextButton') {
          return TextButton(
            key: key,
            onPressed: disabled ? null : activate,
            child: Text(shown['label'] as String),
          );
        }
        return InteractiveMessageButton(
          key: key,
          button: {if (type == 'FilledButton') 'style': 'primary', ...shown},
          busy: widget.busy == button['id'],
          locked: disabled,
          onPressed: activate,
        );
      default:
        return buildInteractiveExtra(
          context,
          node['type'] == 'ProfileAvatar' && node['name'] is Map
              ? {...node, 'name': evaluate(node['name']) as String}
              : node,
          build: (child) => _build(child, scope),
          value: _values[node['key']],
          enabled: !locked && canSubmit,
          onChanged: (value) => _changed(node['key'] as String, value),
        );
    }
  }
}

class _InteractiveTextField extends StatefulWidget {
  const _InteractiveTextField({
    super.key,
    required this.value,
    required this.enabled,
    required this.hintText,
    required this.maxLength,
    required this.onChanged,
  });
  final String value, hintText;
  final bool enabled;
  final int maxLength;
  final ValueChanged<String> onChanged;
  @override
  State<_InteractiveTextField> createState() => _InteractiveTextFieldState();
}

class _InteractiveTextFieldState extends State<_InteractiveTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  @override
  void didUpdateWidget(_InteractiveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MessageComposer(
    embedded: true,
    controller: _controller,
    focusNode: _focus,
    enabled: widget.enabled,
    hintText: widget.hintText,
    maxLength: widget.maxLength,
    onChanged: widget.onChanged,
    action: const SizedBox.shrink(),
  );
}
