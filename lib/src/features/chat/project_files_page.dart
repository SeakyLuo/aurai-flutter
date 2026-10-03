import '../../widgets/empty_data_view.dart';
import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/project_directory.dart';
import 'file_tool_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectFilesPage extends StatefulWidget {
  const ProjectFilesPage({super.key, required this.directory});

  final ProjectDirectory directory;

  @override
  State<ProjectFilesPage> createState() => _ProjectFilesPageState();
}

class _ProjectFilesPageState extends State<ProjectFilesPage> {
  final _platform = AuraiPlatform.instance;
  List<Map<String, Object?>>? _files;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notice(String text, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(text)), kind: kind);

  Future<void> _load() async {
    try {
      final result = await _platform.deviceExtension('listProjectFiles', {
        'uri': widget.directory.uri,
      });
      if (mounted) {
        setState(
          () => _files = (result['files'] as List)
              .map((value) => (value as Map).cast<String, Object?>())
              .toList(),
        );
      }
    } on Object catch (error) {
      if (mounted)
        _notice('项目资料读取失败：${errorMessage(error)}', kind: ToastKind.error);
    }
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final result = await _platform.deviceExtension('importProjectFiles', {
        'uri': widget.directory.uri,
      });
      if (result['cancelled'] != true) await _load();
    } on Object catch (error) {
      if (mounted)
        _notice('项目资料添加失败：${errorMessage(error)}', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '项目文件',
        onBack: _busy ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '添加资料',
            icon: Icons.add_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.add),
            onPressed: _busy ? null : _add,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: files == null
              ? const SizedBox.shrink()
              : files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: const EmptyDataView(
                      title: '还没有项目文件',
                      description: '添加文档、图片或其他素材，AI 可以从项目工作目录中读取。',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  ),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final directory = file['directory'] == true;
                    return ListTile(
                      minTileHeight: 56,
                      leading: FileToolIcon(
                        type: directory
                            ? FileToolIconType.folder
                            : FileToolIconType.document,
                      ),
                      title: Text(
                        file['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: directory
                          ? const Text('文件夹')
                          : Text(_size(file['size'] as int?)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

String _size(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
