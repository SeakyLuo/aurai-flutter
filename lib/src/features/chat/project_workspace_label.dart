import 'package:flutter/material.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import '../../app/ui_action.dart';
import '../../platform/aurai_platform.dart';
import 'project_worktrees_page.dart';
import 'file_tool_icon.dart';

class ProjectWorkspaceLabel extends StatefulWidget {
  const ProjectWorkspaceLabel({super.key, required this.controller});
  final ChatController controller;
  @override
  State<ProjectWorkspaceLabel> createState() => _ProjectWorkspaceLabelState();
}

class _ProjectWorkspaceLabelState extends State<ProjectWorkspaceLabel> {
  String? _key;
  DevelopmentProject? _project;
  bool _available = false;

  Future<void> _load(String id, String conversationId) async {
    await runUiAction(context, () async {
      final project = await widget.controller.projects.forConversation(
        id,
        conversationId,
      );
      if (project.location != ProjectLocation.managed) return;
      final result = await AuraiPlatform.instance
          .deviceExtension('projectDevelopmentOperation', {
            'projectId': id,
            'operation': 'listProjectWorktrees',
            'arguments': <String, Object?>{},
          });
      if (!mounted || widget.controller.activeConversation.id != conversationId)
        return;
      setState(() {
        _project = project;
        _available = result['available'] == true;
      });
    });
  }

  Future<void> _choose() async {
    final conversation = widget.controller.activeConversation;
    await runUiAction(context, () async {
      final base = await widget.controller.projects.read(
        conversation.projectId!,
      );
      if (!mounted) return;
      final selected = await Navigator.push<ProjectWorktreeSelection>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectWorktreesPage(
            project: base,
            controller: widget.controller,
          ),
        ),
      );
      if (selected != null) {
        await widget.controller.selectConversationWorkspace(
          conversation.id,
          selected.id == null
              ? base
              : base.inWorktree(selected.id!, selected.name),
        );
      }
      if (mounted) setState(() => _key = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.controller.activeConversation;
    final id = conversation.projectId;
    if (id == null) return const SizedBox.shrink();
    final key =
        '$id:${conversation.id}:${DevelopmentProjects.worktreeRevision}';
    if (_key != key) {
      _key = key;
      _project = null;
      _available = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(id, conversation.id);
      });
    }
    final project = _project;
    if (project == null || !_available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.controller.isBusy ? null : _choose,
          icon: const FileToolIcon(type: FileToolIconType.folder),
          label: Text(
            '工作目录 · ${project.worktreeDeleted ? '请选择' : project.worktreeName ?? '主目录'}',
          ),
        ),
      ),
    );
  }
}
