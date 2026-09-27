import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../memory/memory_controller.dart';
import '../../memory/memory_summary_page.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'file_tool_icon.dart';
import 'project_editor_page.dart';
import 'project_icon.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectProfilePage extends StatefulWidget {
  const ProjectProfilePage({
    super.key,
    required this.controller,
    required this.project,
  });

  final ChatController controller;
  final DevelopmentProject project;

  @override
  State<ProjectProfilePage> createState() => _ProjectProfilePageState();
}

class _ProjectProfilePageState extends State<ProjectProfilePage> {
  late DevelopmentProject _project = widget.project;
  String? _localPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    try {
      if (_project.location == ProjectLocation.managed) {
        setState(() => _localPath = 'Aurai 工作区 / ${_project.name}');
        return;
      }
      final output = await AuraiPlatform.instance.deviceExtension(
        'getDocumentFolders',
      );
      final folder = (output['folders'] as List)
          .map((value) => (value as Map).cast<String, Object?>())
          .singleWhere((value) => value['uri'] == _project.rootUri);
      if (mounted) {
        setState(
          () => _localPath = [
            folder['source'] as String,
            folder['path'] as String,
          ].where((value) => value.isNotEmpty).join(' / '),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('本地路径读取失败：${errorMessage(error)}')),
        );
      }
    }
  }

  Future<void> _edit() async {
    final project = await Navigator.push<DevelopmentProject>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProjectEditorPage(controller: widget.controller, project: _project),
      ),
    );
    if (!mounted) return;
    final refreshed =
        project ?? await widget.controller.projects.read(_project.id);
    if (mounted) setState(() => _project = refreshed);
    await _loadPath();
  }

  Future<void> _memory() async {
    final project = await Navigator.push<DevelopmentProject>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProjectMemoryPage(controller: widget.controller, project: _project),
      ),
    );
    if (!mounted) return;
    final refreshed =
        project ?? await widget.controller.projects.read(_project.id);
    if (mounted) setState(() => _project = refreshed);
  }

  Future<void> _openPath() async {
    try {
      await AuraiPlatform.instance.openProjectFolder(_project.rootUri);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法打开本地路径：${errorMessage(error)}')),
        );
      }
    }
  }

  Future<void> _copyProjectId() async {
    await Clipboard.setData(ClipboardData(text: _project.id));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已复制项目 ID')));
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => DeleteConfirmationDialog(
        title: '移除项目？',
        description: _project.location == ProjectLocation.managed
            ? '项目中的会话会移回普通会话列表，Aurai 工作区内的项目文件会被删除，无法恢复。'
            : '项目中的会话会移回普通会话列表，手机文件夹及其中的内容不会删除。',
        confirmLabel: '移除',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.removeProject(_project);
      if (mounted) Navigator.pop(context, true);
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
        title: '',
        titleWidget: const SizedBox.shrink(),
        onBack: _busy ? null : () => Navigator.pop(context),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: settingsPagePadding(
              context,
              const EdgeInsets.fromLTRB(16, 12, 16, 32),
            ),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Center(
                    child: ProjectIcon(
                      icon: _project.icon,
                      color: _project.iconColor,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _project.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_project.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _project.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _row(
                '项目信息',
                ConversationMenuIcon(
                  type: ConversationMenuIconType.rename,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                _edit,
                subtitle: _project.gitRemoteUrl.isEmpty
                    ? '项目名称、介绍、图标和 Git 远端'
                    : _project.gitRemoteUrl,
              ),
              _row(
                '项目记忆',
                SettingsIcon(
                  type: SettingsIconType.memory,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                _memory,
                subtitle: _project.memoryMode == ProjectMemoryMode.shared
                    ? '默认记忆'
                    : '仅限项目的记忆',
              ),
              _row(
                '项目文件夹',
                FileToolIcon(
                  type: FileToolIconType.folder,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                _openPath,
                subtitle: _localPath ?? '',
              ),
              const SizedBox(height: 14),
              DialogActionButton(
                text: '复制项目 ID',
                role: DialogActionRole.secondary,
                onPressed: _busy ? null : _copyProjectId,
              ),
              const SizedBox(height: 12),
              DialogActionButton(
                text: '移除项目',
                role: DialogActionRole.reject,
                onPressed: _busy ? null : _remove,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _row(
    String title,
    Widget icon,
    VoidCallback onTap, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: icon,
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const SettingsIcon(type: SettingsIconType.chevron),
        onTap: _busy ? null : onTap,
      ),
    ),
  );
}

class ProjectMemoryPage extends StatefulWidget {
  const ProjectMemoryPage({
    super.key,
    required this.controller,
    required this.project,
  });

  final ChatController controller;
  final DevelopmentProject project;

  @override
  State<ProjectMemoryPage> createState() => _ProjectMemoryPageState();
}

class _ProjectMemoryPageState extends State<ProjectMemoryPage> {
  late DevelopmentProject _project = widget.project;
  MemoryController? _memory;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final memory = await widget.controller.projectMemory(_project);
      if (mounted) setState(() => _memory = memory);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('记忆读取失败：${errorMessage(error)}')),
      );
      Navigator.pop(context, _project);
    }
  }

  Future<void> _chooseMode() async {
    final mode = await showModalBottomSheet<ProjectMemoryMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => _ProjectMemoryModeSheet(selected: _project.memoryMode),
    );
    if (mode == null || mode == _project.memoryMode || !mounted) return;
    setState(() => _busy = true);
    try {
      final project = await widget.controller.setProjectMemoryMode(
        _project,
        mode,
      );
      if (mounted) setState(() => _project = project);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('记忆范围保存失败：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    if (memory == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '项目记忆',
          onBack: () => Navigator.pop(context, _project),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return MemorySummaryPage(
      memory: memory,
      title: '项目记忆',
      actions: [
        SettingsGlassAction(
          label: '记忆范围',
          icon: Icons.tune_rounded,
          iconWidget: SettingsIcon(
            type: SettingsIconType.modelSettings,
            color: SettingsGlassAction.foregroundColor(
              context,
              enabled: !_busy,
            ),
          ),
          onPressed: _busy ? null : _chooseMode,
        ),
      ],
    );
  }
}

class _ProjectMemoryModeSheet extends StatelessWidget {
  const _ProjectMemoryModeSheet({required this.selected});

  final ProjectMemoryMode selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    '记忆范围',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 18),
            _option(
              context,
              ProjectMemoryMode.shared,
              '默认记忆',
              'AI 可以读取自己的私有记忆，并共同使用这个项目的共享记忆。',
              colors,
            ),
            const SizedBox(height: 10),
            _option(
              context,
              ProjectMemoryMode.projectOnly,
              '仅限项目的记忆',
              'AI 只使用这个项目的共享记忆，不读取项目外的私有记忆。',
              colors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    ProjectMemoryMode mode,
    String title,
    String description,
    ColorScheme colors,
  ) {
    final active = selected == mode;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, mode),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.onSurface : Colors.transparent,
                  border: Border.all(
                    color: active ? colors.onSurface : colors.outline,
                    width: 1.4,
                  ),
                ),
                child: active
                    ? SettingsIcon(
                        type: SettingsIconType.check,
                        color: colors.surface,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
