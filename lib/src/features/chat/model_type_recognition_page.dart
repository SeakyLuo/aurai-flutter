import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import '../../providers/model_type_recognition.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'app_dialog.dart';
import 'choice_sheet.dart';
import 'dialog_action_button.dart';
import 'glass_surface.dart';
import 'model_type_preview_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

typedef ModelTypeSettings = ({String path, Map<String, ModelPurpose> mappings});

class ModelTypeRecognitionPage extends StatefulWidget {
  const ModelTypeRecognitionPage({
    super.key,
    required this.config,
    required this.readOnly,
  });
  final ModelConfig config;
  final bool readOnly;
  @override
  State<ModelTypeRecognitionPage> createState() =>
      _ModelTypeRecognitionPageState();
}

class _ModelTypeRecognitionPageState extends State<ModelTypeRecognitionPage> {
  late final _path = TextEditingController(
    text: widget.config.details?.modelPurposeField ?? '',
  );
  late final _initialMappings =
      widget.config.details?.modelTypeMappings.isNotEmpty == true
      ? widget.config.details!.modelTypeMappings
      : ModelTypeRecognition.defaults;
  late final _typeValues = {
    for (final type in ModelPurpose.values)
      type: TextEditingController(
        text: [
          for (final entry in _initialMappings.entries)
            if (entry.value == type) entry.key,
        ].join(', '),
      ),
  };
  Map<String, ModelPurpose> get _mappings => {
    for (final entry in _typeValues.entries)
      for (final value in _values(entry.value.text)) value: entry.key,
  };
  Iterable<String> _values(String text) => text
      .split(RegExp(r'[,，\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);

  final _catalog = ModelCatalog();
  List<Map<String, dynamic>>? _entries;
  bool _allowPop = false;
  String get _activePath => _path.text.trim();
  bool get _dirty =>
      _activePath != (widget.config.details?.modelPurposeField ?? '') ||
      !mapEquals(_mappings, _initialMappings);

  @override
  void dispose() {
    _path.dispose();
    for (final controller in _typeValues.values) {
      controller.dispose();
    }
    _catalog.close();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadEntries() async {
    if (_entries != null) return _entries!;
    final entries = await _catalog.loadEntries(widget.config);
    _entries = entries;
    return entries;
  }

  Future<void> _preview() async {
    if (!await runUiAction(context, () async {
      _validate();
    }))
      return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await showModelTypePreviewSheet(
      context,
      loadEntries: _loadEntries,
      purposeLabel: _purposeLabel,
      onOpen: _sample,
    );
  }

  Future<void> _save() async {
    await runUiAction(context, () async {
      _validate();
      setState(() => _allowPop = true);
      Navigator.pop(context, (
        path: _activePath,
        mappings: Map<String, ModelPurpose>.from(_mappings),
      ));
    });
  }

  Future<void> _back() async {
    if (!widget.readOnly && _dirty) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => const TaskUnsavedDialog(description: '模型类型识别还有未保存的修改。'),
      );
      if (!mounted || action == null) return;
      if (action == 'save') {
        await _save();
        return;
      }
      if (action != 'discard') return;
    }
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  ({String? path, Object? value}) _raw(Map<String, dynamic> entry) =>
      ModelTypeRecognition.read(entry, _activePath);

  Set<String> _fields() {
    final fields = <String>{};
    void visit(Map source, String prefix) {
      for (final entry in source.entries) {
        final path = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        if (entry.value is Map) {
          visit(entry.value as Map, path);
        } else if (entry.value is String ||
            entry.value is num ||
            entry.value is List) {
          fields.add(path);
        }
      }
    }

    for (final entry in _entries!) {
      visit(entry, '');
    }
    return fields;
  }

  Future<void> _chooseField() => runUiAction(context, () async {
    await _loadEntries();
    if (!mounted) return;
    final fields = _fields().toList()..sort();
    final selected = await showChoiceSheet<String>(
      context,
      title: '选择模型类型字段',
      selected: _path.text,
      choices: [for (final field in fields) (value: field, label: field)],
    );
    if (mounted && selected != null) setState(() => _path.text = selected);
  }).then((_) {});

  void _validate() {
    if (_activePath.isNotEmpty &&
        !RegExp(r'^[^.\s]+(?:\.[^.\s]+)*$').hasMatch(_activePath)) {
      throw ArgumentError('模型类型字段路径格式不正确');
    }
    final assigned = <String, ModelPurpose>{};
    for (final entry in _typeValues.entries) {
      for (final value in _values(entry.value.text)) {
        if (assigned.containsKey(value) && assigned[value] != entry.key) {
          throw ArgumentError('“$value”不能同时对应多个模型类型');
        }
        assigned[value] = entry.key;
      }
    }
  }

  Future<void> _sample(Map<String, dynamic> entry) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '模型返回数据',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('识别字段'),
              subtitle: Text(_raw(entry).path ?? '未找到类型字段'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('字段值'),
              subtitle: Text(jsonEncode(_raw(entry).value)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('识别结果'),
              subtitle: Text(_purposeLabel(entry)),
            ),
            const SizedBox(height: 16),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(entry),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            DialogActionButton(
              text: '关闭',
              role: DialogActionRole.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      ),
    ),
  );

  String _purposeLabel(Map<String, dynamic> entry) {
    final types = ModelTypeRecognition.purposes(entry, _activePath, _mappings);
    return types.isEmpty ? '未识别' : types.map(_typeName).join('、');
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  String _typeName(ModelPurpose type) => switch (type) {
    ModelPurpose.text => '文本',
    ModelPurpose.imageGeneration => '图片',
    ModelPurpose.videoGeneration => '视频',
    ModelPurpose.musicGeneration => '音乐',
  };

  Widget _ruleField(ModelPurpose type) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(_typeName(type)),
        if (widget.readOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(_typeValues[type]!.text),
          )
        else
          TextField(
            controller: _typeValues[type],
            autocorrect: false,
            enableSuggestions: false,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontSize: 15),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '多个值用逗号分隔',
              filled: true,
              fillColor: settingsFieldColor(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 18, right: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '类型字段',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!widget.readOnly)
              TextButton(onPressed: _chooseField, child: const Text('选择字段')),
          ],
        ),
      ),
      if (widget.readOnly)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(_activePath.isEmpty ? '自动查找' : _activePath),
        )
      else
        TextField(
          controller: _path,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 15),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '自动查找，也可填写字段路径',
            filled: true,
            fillColor: settingsFieldColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      const SizedBox(height: 24),
      for (final type in ModelPurpose.values) _ruleField(type),
      if (!widget.readOnly)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
          child: Text(
            '全部留空恢复默认规则。',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '模型类型识别',
          onBack: _back,
          actions: [
            if (!widget.readOnly)
              SettingsGlassActionSurface(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoundAction(
                      label: '预览效果',
                      icon: Icons.play_arrow_rounded,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.play,
                      ),
                      onPressed: _preview,
                    ),
                    SizedBox(
                      height: 18,
                      child: VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    RoundAction(
                      label: '保存',
                      icon: Icons.check_rounded,
                      iconWidget: SettingsIcon(
                        type: SettingsIconType.check,
                        color: SettingsGlassAction.foregroundColor(
                          context,
                          enabled: _dirty,
                        ),
                      ),
                      onPressed: _dirty ? _save : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: SettingsPageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 20, 16, 32),
                ),
                children: [_controls()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
