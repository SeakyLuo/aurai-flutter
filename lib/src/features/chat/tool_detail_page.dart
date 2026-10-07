import '../../app/glass_notice.dart';
import 'resource_scope_picker.dart';
import '../../domain/resource_scope.dart';
import 'package:flutter/foundation.dart';
import 'delete_confirmation_dialog.dart';
import 'question_icon.dart';
import '../../skills/skill_icon_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/agent_models.dart';
import '../../domain/tool_models.dart';
import '../../domain/tool_customization.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'conversation_menu_icon.dart';
import 'tool_action_icon.dart';
import 'tool_payload_section.dart';

class ToolDetailPage extends StatefulWidget {
  const ToolDetailPage({super.key, required this.tool});
  final ToolDefinition tool;
  @override
  State<ToolDetailPage> createState() => _ToolDetailPageState();
}

class _ToolDetailPageState extends State<ToolDetailPage> {
  late ToolDefinition _tool = ToolCustomizations.apply(widget.tool);
  late String _savedTitle = toolTitle(_tool.name);
  late String _savedIcon = ToolCustomizations.values[_tool.name]?.icon ?? '';
  late String _icon = _savedIcon;
  late List<ResourceScope> _scopes =
      ToolCustomizations.values[_tool.name]?.scopes ?? [];
  List<Map<String, Object?>> _groups = [];
  List<Map<String, Object?>> _projects = [];
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final rows = await Future.wait([
        ToolCustomizations.groups(),
        ToolCustomizations.projects(),
      ]);
      if (mounted)
        setState(() {
          _groups = rows[0];
          _projects = rows[1];
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(error.toString())),
          kind: ToastKind.error,
        );
    }
  }

  late final _name = TextEditingController(text: _savedTitle);
  late final _description = TextEditingController(text: _tool.description);
  late final _summary = TextEditingController(text: _tool.summary);
  late final _parameters = TextEditingController(
    text: _encode(_tool.inputSchema),
  );
  bool _editing = false, _saving = false, _allowPop = false;
  static String _encode(Map<String, Object?> value) =>
      const JsonEncoder.withIndent('  ').convert(value);
  bool get _changed =>
      _name.text != _savedTitle ||
      _icon != _savedIcon ||
      !setEquals(
        _scopes.toSet(),
        (ToolCustomizations.values[_tool.name]?.scopes ?? []).toSet(),
      ) ||
      _description.text != _tool.description ||
      _summary.text != _tool.summary ||
      _parameters.text != _encode(_tool.inputSchema);

  Future<void> _copyName() async {
    await Clipboard.setData(ClipboardData(text: _savedTitle));
    if (mounted) {
      ScaffoldMessenger.of(context).showToast(
        const SnackBar(content: Text('工具名称已复制')),
        kind: ToastKind.success,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _summary.dispose();
    _parameters.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_editing && _changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => const DeleteConfirmationDialog(
          title: '放弃未保存的修改？',
          description: '工具的修改尚未保存。',
          confirmLabel: '放弃修改',
          cancelLabel: '继续编辑',
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    if (_editing) {
      FocusScope.of(context).unfocus();
      setState(() {
        _name.text = _savedTitle;
        _description.text = _tool.description;
        _summary.text = _tool.summary;
        _parameters.text = _encode(_tool.inputSchema);
        _icon = _savedIcon;
        _scopes = ToolCustomizations.values[_tool.name]?.scopes ?? [];
        _editing = false;
      });
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_name.text.trim().isEmpty) {
        throw const FormatException('名称不能为空');
      }
      if (_description.text.trim().isEmpty && _summary.text.trim().isEmpty) {
        throw const FormatException('简述和完整说明至少填写一项');
      }
      if (_summary.text.trim().characters.length > 300)
        throw const FormatException('简述最多 300 字');
      final decoded = jsonDecode(_parameters.text);
      if (decoded is! Map ||
          decoded['type'] != 'object' ||
          decoded['properties'] is! Map) {
        throw const FormatException('调用参数需要包含 object 类型和 properties 字段');
      }
      final requiredFields = decoded['required'];
      if (requiredFields != null &&
          (requiredFields is! List ||
              requiredFields.any(
                (key) =>
                    key is! String ||
                    !(decoded['properties'] as Map).containsKey(key),
              ))) {
        throw const FormatException('必填参数必须对应已定义的参数名称');
      }
      final customization = ToolCustomization(
        title: _name.text.trim(),
        icon: _icon,
        scopes: _scopes,
        description: _description.text,
        summary: _summary.text.trim(),
        inputSchema: decoded.cast<String, Object?>(),
      );
      await ToolCustomizations.save(_tool.name, customization);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _tool = ToolCustomizations.apply(_tool);
        _savedTitle = customization.title!;
        _savedIcon = _icon;
        _name.text = _savedTitle;
        _parameters.text = _encode(_tool.inputSchema);
        _summary.text = _tool.summary;
        _editing = false;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(
            content: Text(
              error is FormatException ? error.message : '保存失败：$error',
            ),
          ),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving && (!_editing || _changed);
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: enabled ? 1 : .3);
    return PopScope(
      canPop: _allowPop || (!_saving && !_editing),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '工具详情',
          onBack: _back,
          leadingAction: _editing
              ? SettingsGlassAction(
                  label: '退出编辑',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: _saving ? null : _back,
                )
              : null,
          actions: [
            SettingsGlassAction(
              label: _editing ? '保存' : '编辑',
              icon: Icons.check,
              iconWidget: _editing
                  ? SettingsIcon(type: SettingsIconType.check, color: color)
                  : ConversationMenuIcon(
                      type: ConversationMenuIconType.rename,
                      color: color,
                    ),
              onPressed: !enabled
                  ? null
                  : _editing
                  ? _save
                  : () => setState(() => _editing = true),
            ),
          ],
        ),
        body: SettingsPageBody(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Text(
                        '名称',
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: _editing ? null : _copyName,
                      child: AbsorbPointer(
                        absorbing: !_editing,
                        child: TextField(
                          controller: _name,
                          readOnly: !_editing,
                          enabled: !_saving,
                          style: const TextStyle(fontSize: 16),
                          onChanged: (_) => setState(() {}),
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 6, right: 4),
                              child: Tooltip(
                                message: '选择工具图标',
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: !_editing || _saving
                                        ? null
                                        : () async {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            final icon =
                                                await showSkillIconPicker(
                                                  context,
                                                  _icon.substring(6),
                                                  title: '选择工具图标',
                                                );
                                            if (mounted && icon != null) {
                                              setState(
                                                () => _icon = 'skill:$icon',
                                              );
                                            }
                                          },
                                    child: SizedBox.square(
                                      dimension: 48,
                                      child: Center(
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            BlendMode.srcIn,
                                          ),
                                          child: ToolActionIcon(
                                            toolName: _tool.name,
                                            iconName: _icon,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 60,
                              minHeight: 48,
                            ),
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResourceScopeField(
                      projects: _projects,
                      scopes: _scopes,
                      groups: _groups,
                      onChanged: !_editing || _saving
                          ? null
                          : (scopes) => setState(() => _scopes = scopes),
                    ),
                    _label('简述'),
                    _editing
                        ? _editor(_summary, summary: true)
                        : _surface(
                            SelectableText(
                              _tool.summary.trim().isEmpty
                                  ? '未填写，搜索时使用完整说明的摘要。'
                                  : _tool.summary,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ),
                    _label('完整说明'),
                    _editing
                        ? _editor(_description)
                        : _surface(
                            SelectableText(
                              _tool.description.trim().isEmpty
                                  ? '未填写，调用时使用简述。'
                                  : _tool.description,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ),
                    if (_editing) ...[
                      _label('调用参数'),
                      _editor(_parameters, code: true),
                    ] else
                      ToolPayloadSection(
                        title: '调用参数',
                        headerPadding: const EdgeInsets.fromLTRB(18, 14, 8, 2),
                        titleStyle: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        json: jsonEncode(_tool.modelInputSchema),
                        missing: '无参数',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editor(
    TextEditingController controller, {
    bool code = false,
    bool summary = false,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    maxLines: null,
    maxLength: summary ? 300 : null,
    autocorrect: !code,
    enableSuggestions: !code,
    style: const TextStyle(fontSize: 15, height: 1.5),
    onChanged: (_) => setState(() {}),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    decoration: InputDecoration(
      helperText: summary
          ? '通常 30–100 字，复杂工具最多 300 字。与完整说明至少填一项；留空时搜索展示完整说明的前 300 字。'
          : null,
      helperMaxLines: 3,
      filled: true,
      fillColor: settingsFieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
    ),
    child: child,
  );
}
