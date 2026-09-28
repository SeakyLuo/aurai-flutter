import 'package:flutter/material.dart';
import '../../storage/project_directory.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'file_tool_icon.dart';
import 'project_directory_picker.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectDirectorySheet extends StatefulWidget {
  const ProjectDirectorySheet({super.key, required this.excluded});
  final Set<String> excluded;
  @override
  State<ProjectDirectorySheet> createState() => _ProjectDirectorySheetState();
}

class _ProjectDirectorySheetState extends State<ProjectDirectorySheet> {
  List<ProjectDirectory> _selected = [];

  Future<void> _newDirectory() async {
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => const _DirectoryNameDialog(),
    );
    if (name != null && mounted) Navigator.pop(context, (name, _selected));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
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
                  '添加目录',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              SettingsGlassAction(
                label: '添加',
                icon: Icons.check_rounded,
                iconWidget: SettingsIcon(
                  type: SettingsIconType.check,
                  color: SettingsGlassAction.foregroundColor(
                    context,
                    enabled: _selected.isNotEmpty,
                  ),
                ),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, (null, _selected)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ProjectDirectoryPicker(
            selected: _selected,
            excluded: widget.excluded,
            onChanged: (value) => setState(() => _selected = value),
            header: ListTile(
              leading: const FileToolIcon(type: FileToolIconType.folder),
              title: const Text('新建目录', style: TextStyle(fontSize: 15)),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: _newDirectory,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DirectoryNameDialog extends StatefulWidget {
  const _DirectoryNameDialog();
  @override
  State<_DirectoryNameDialog> createState() => _DirectoryNameDialogState();
}

class _DirectoryNameDialogState extends State<_DirectoryNameDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '新建目录',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(hintText: '目录名称'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DialogActionButton(
            text: '创建',
            role: DialogActionRole.primary,
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _name.text.trim()),
          ),
          const SizedBox(height: 8),
          DialogActionButton(
            text: '取消',
            role: DialogActionRole.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
