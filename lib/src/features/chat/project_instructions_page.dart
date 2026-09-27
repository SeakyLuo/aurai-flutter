import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectInstructionsPage extends StatefulWidget {
  const ProjectInstructionsPage({
    super.key,
    required this.controller,
    required this.project,
  });

  final ChatController controller;
  final DevelopmentProject project;

  @override
  State<ProjectInstructionsPage> createState() =>
      _ProjectInstructionsPageState();
}

class _ProjectInstructionsPageState extends State<ProjectInstructionsPage> {
  late final _instructions = TextEditingController(
    text: widget.project.instructions,
  );
  bool _saving = false;

  bool get _changed => _instructions.text.trim() != widget.project.instructions;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_changed || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final project = await widget.controller.setProjectInstructions(
        widget.project,
        _instructions.text,
      );
      if (mounted) Navigator.pop(context, project);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '自定义指令',
        onBack: _saving ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
            onPressed: _changed && !_saving ? _save : null,
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      '告诉 AI 在这个项目中应遵循的约定、工作方式和输出要求。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _instructions,
                    enabled: !_saving,
                    autofocus: true,
                    minLines: 10,
                    maxLines: null,
                    maxLength: projectInstructionsMaxLength,
                    onChanged: (_) => setState(() {}),
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: '例如：修改前先阅读项目文档；提交信息使用中文……',
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
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
