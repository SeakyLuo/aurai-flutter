import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../storage/project_directory.dart';
import 'project_directory_picker.dart';
import 'file_tool_icon.dart';
import '../../skills/skill_icon.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'app_dialog.dart';
import 'avatar_background.dart';
import 'avatar_symbol_picker.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'project_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectEditorPage extends StatefulWidget {
  const ProjectEditorPage({super.key, required this.controller, this.project});
  final ChatController controller;
  final DevelopmentProject? project;

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late final _instructions = TextEditingController(
    text: widget.project?.instructions,
  );
  late String _icon = widget.project?.icon ?? 'file';
  late String _iconColor = widget.project?.iconColor ?? 'ink';
  bool _managed = true;
  List<ProjectDirectory> _directories = [];
  bool _busy = false;
  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim().characters.length <= projectNameMaxLength &&
      _instructions.text.trim().characters.length <=
          projectInstructionsMaxLength &&
      (widget.project != null || _managed || _directories.isNotEmpty);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Future<void> _chooseIcon() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final icon = await showAvatarSymbolPicker(
      context,
      selected: _icon,
      color: _iconColor,
      name: _name.text,
      symbols: skillIconChoices,
      previewBuilder: (value) => SizedBox.square(
        dimension: 44,
        child: Center(
          child: ProjectIcon(icon: value, color: _iconColor, size: 26),
        ),
      ),
    );
    if (mounted && icon != null) setState(() => _icon = icon);
  }

  Future<void> _iconActions(BuildContext anchorContext) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final action = await showHeaderActionMenu(
      anchorContext,
      preserveIconColors: const {'icon', 'color'},
      items: [
        (
          value: 'icon',
          label: '修改图标',
          icon: ProjectIcon(icon: _icon, color: _iconColor),
        ),
        (
          value: 'color',
          label: '修改颜色',
          icon: _ProjectColorSwatch(color: _projectColor(context, _iconColor)),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'icon') {
      await _chooseIcon();
    } else if (action == 'color') {
      final color = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => _ProjectColorDialog(selected: _iconColor),
      );
      if (mounted && color != null) setState(() => _iconColor = color);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      final description = _description.text.trim();
      final instructions = _instructions.text.trim();
      final project = widget.project != null
          ? await widget.controller.updateProjectProfile(
              widget.project!,
              name: name,
              description: description,
              instructions: instructions,
              icon: _icon,
              iconColor: _iconColor,
            )
          : _managed
          ? await widget.controller.createManagedProject(
              name,
              _icon,
              _iconColor,
              description: description,
              instructions: instructions,
              directories: _directories,
              directoryNames: [name],
            )
          : await widget.controller.createExternalProject(
              name,
              _icon,
              _iconColor,
              _directories,
              description: description,
              instructions: instructions,
            );
      if (mounted) Navigator.pop(context, project);
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: widget.project == null ? '创建项目' : '编辑项目',
        onBack: _busy ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassActionSurface(
            child: RoundAction(
              label: _busy ? '正在保存' : '保存',
              icon: Icons.check_rounded,
              iconWidget: Opacity(
                opacity: _canSave && !_busy ? 1 : .3,
                child: const SettingsIcon(type: SettingsIconType.check),
              ),
              onPressed: _canSave && !_busy ? _save : null,
            ),
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
                  TextField(
                    controller: _name,
                    autofocus: true,
                    enabled: !_busy,
                    maxLength: projectNameMaxLength,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      hintText: '项目名称',
                      counterText: '',
                      filled: true,
                      fillColor: settingsFieldColor(context),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 6, right: 4),
                        child: Builder(
                          builder: (iconContext) => Tooltip(
                            message: '修改项目图标',
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: _busy
                                    ? null
                                    : () => _iconActions(iconContext),
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: Center(
                                    child: ProjectIcon(
                                      icon: _icon,
                                      color: _iconColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                  if (widget.project != null) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '项目介绍',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: '作为背景信息提供给 AI',
                        filled: true,
                        fillColor: settingsFieldColor(context),
                        contentPadding: const EdgeInsets.all(18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '自定义指令',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructions,
                      enabled: !_busy,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: projectInstructionsMaxLength,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '设置项目中 AI 应遵循的约定和工作方式',
                        filled: true,
                        fillColor: settingsFieldColor(context),
                        contentPadding: const EdgeInsets.all(18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (widget.project == null) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '工作目录',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProjectDirectoryPicker(
                      selected: _directories,
                      enabled: !_busy,
                      onChanged: (directories) =>
                          setState(() => _directories = directories),
                      header: ListTile(
                        enabled: !_busy,
                        leading: const FileToolIcon(
                          type: FileToolIconType.folder,
                        ),
                        title: const Text(
                          'Aurai 工作区',
                          style: TextStyle(fontSize: 15),
                        ),
                        subtitle: const Text(
                          '使用项目名称创建目录',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: _managed
                            ? const SettingsIcon(type: SettingsIconType.check)
                            : null,
                        onTap: _busy
                            ? null
                            : () => setState(() => _managed = !_managed),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Color _projectColor(BuildContext context, String value) => value == 'default'
    ? Theme.of(context).colorScheme.onSurface
    : AvatarBackground.decode(value).start;

class _ProjectColorSwatch extends StatelessWidget {
  const _ProjectColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ProjectColorDialog extends StatelessWidget {
  const _ProjectColorDialog({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final choices = <(String, String, Color)>[
      for (final key in const [
        'ink',
        'red',
        'orange',
        'yellow',
        'green',
        'cyan',
        'blue',
        'indigo',
        'violet',
        'rose',
        'slate',
      ])
        (key, avatarColors[key]!.$1, avatarColors[key]!.$2),
      ('default', '默认', Theme.of(context).colorScheme.onSurface),
    ];
    return AppDialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '修改颜色',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final choice in choices)
                  Semantics(
                    label: choice.$2,
                    selected: choice.$1 == selected,
                    button: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        radius: 24,
                        onTap: () => Navigator.pop(context, choice.$1),
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 2,
                              color: choice.$1 == selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: choice.$3,
                            ),
                            child: choice.$1 == selected
                                ? Center(
                                    child: SettingsIcon(
                                      type: SettingsIconType.check,
                                      color: AvatarBackground(
                                        choice.$3,
                                        choice.$3,
                                      ).foreground,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
