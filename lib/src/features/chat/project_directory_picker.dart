import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/project_directory.dart';
import 'file_tool_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectDirectoryPicker extends StatefulWidget {
  const ProjectDirectoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.excluded = const {},
    this.header,
  });
  final List<ProjectDirectory> selected;
  final void Function(List<ProjectDirectory>) onChanged;
  final bool enabled;
  final Set<String> excluded;
  final Widget? header;
  @override
  State<ProjectDirectoryPicker> createState() => _ProjectDirectoryPickerState();
}

class _ProjectDirectoryPickerState extends State<ProjectDirectoryPicker> {
  List<ProjectDirectory> _folders = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    runUiAction(context, _load);
  }

  Future<void> _load() async {
    final result = await AuraiPlatform.instance.deviceExtension(
      'getDocumentFolders',
    );
    final folders = (result['folders'] as List)
        .cast<Map>()
        .map(
          (folder) => ProjectDirectory(
            uri: folder['uri'] as String,
            name: folder['name'] as String,
          ),
        )
        .toList();
    if (mounted) setState(() => _folders = folders);
  }

  Future<void> _choose() async {
    setState(() => _busy = true);
    await runUiAction(context, () async {
      final result = await AuraiPlatform.instance.deviceExtension(
        'requestDocumentFolder',
        {'uri': null},
      );
      if (result['cancelled'] == true) return;
      await _load();
      if (!mounted) return;
      final uri = result['selectedUri'] as String;
      if (widget.excluded.contains(uri)) throw StateError('此目录已加入项目');
      final folder = _folders.singleWhere((item) => item.uri == uri);
      if (!widget.selected.any((item) => item.uri == uri)) {
        widget.onChanged([...widget.selected, folder]);
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.header != null) widget.header!,
        for (final folder in _folders.where(
          (item) => !widget.excluded.contains(item.uri),
        ))
          _tile(
            folder.name,
            '手机文件夹',
            widget.selected.any((item) => item.uri == folder.uri),
            () {
              final selected = [...widget.selected];
              if (selected.any((item) => item.uri == folder.uri)) {
                selected.removeWhere((item) => item.uri == folder.uri);
              } else {
                selected.add(folder);
              }
              widget.onChanged(selected);
            },
          ),
        ListTile(
          enabled: widget.enabled && !_busy,
          minTileHeight: 60,
          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          leading: const FileToolIcon(type: FileToolIconType.folder),
          title: const Text('选择手机文件夹', style: TextStyle(fontSize: 15)),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: widget.enabled && !_busy ? _choose : null,
        ),
      ],
    ),
  );

  Widget _tile(
    String title,
    String subtitle,
    bool selected,
    VoidCallback onTap,
  ) => ListTile(
    enabled: widget.enabled && !_busy,
    minTileHeight: 64,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: const FileToolIcon(type: FileToolIconType.folder),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
    trailing: selected
        ? const SettingsIcon(type: SettingsIconType.check)
        : null,
    onTap: widget.enabled && !_busy ? onTap : null,
  );
}
