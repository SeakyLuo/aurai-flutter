import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/aurai_platform.dart';
import '../../utils/widget_utils.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'file_tool_icon.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class DocumentFoldersPage extends StatefulWidget {
  const DocumentFoldersPage({super.key});
  @override
  State<DocumentFoldersPage> createState() => _DocumentFoldersPageState();
}

class _DocumentFoldersPageState extends State<DocumentFoldersPage>
    with WidgetsBindingObserver {
  final _platform = AuraiPlatform.instance;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  List<Map<String, Object?>>? _folders;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _perform(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _perform(_load);
  }

  void _notice(String message) =>
      _messenger.currentState!.showSnackBar(SnackBar(content: Text(message)));
  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on PlatformException catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final output = await _platform.deviceExtension('getDocumentFolders');
    if (mounted)
      setState(
        () => _folders = (output['folders'] as List)
            .map((item) => (item as Map).cast<String, Object?>())
            .toList(),
      );
  }

  Future<void> _choose([String? uri]) => _perform(() async {
    final result = await _platform.deviceExtension('requestDocumentFolder', {
      'uri': uri,
    });
    await _load();
    if (mounted && result['cancelled'] != true) _notice('文件夹已授权');
  });
  Future<void> _open(Map<String, Object?> folder) async {
    if (folder['readable'] != true) {
      await _choose(folder['uri'] as String);
      return;
    }
    await _perform(() async {
      await _platform.manageDocumentFolder(
        'openDocumentFolder',
        folder['uri'] as String,
      );
    });
    await _load();
  }

  Future<void> _remove(Map<String, Object?> folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .16),
      builder: (_) => DeleteConfirmationDialog(
        title: '移除文件夹授权？',
        description: 'Aurai 将不再访问“${folder['name']}”。文件夹和里面的文件不会被删除。',
        confirmLabel: '移除授权',
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      await _platform.manageDocumentFolder(
        'removeDocumentFolder',
        folder['uri'] as String,
      );
      await _load();
      if (mounted) _notice('已移除授权');
    });
  }

  Future<void> _rename(Map<String, Object?> folder) async {
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .16),
      builder: (_) => _FolderNameDialog(name: folder['name'] as String),
    );
    if (name == null || !mounted) return;
    await _perform(() async {
      await _platform.manageDocumentFolder(
        'renameDocumentFolder',
        folder['uri'] as String,
        name: name,
      );
      await _load();
      if (mounted) _notice('已修改显示名称');
    });
  }

  @override
  Widget build(BuildContext context) {
    final folders = _folders;
    final colors = Theme.of(context).colorScheme;
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: SettingsAppBar(
          title: '授权文件夹',
          onBack: () => Navigator.maybePop(context),
          actions: [
            SettingsGlassAction(
              label: '添加文件夹',
              icon: Icons.add_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.add),
              onPressed: _busy ? null : () => _choose(),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: folders == null
                  ? const SizedBox.shrink()
                  : folders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FileToolIcon(type: FileToolIconType.folder),
                          const SizedBox(height: 16),
                          const Text(
                            '选择要交给 Aurai 的文件夹',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '读取文档、查找文件，并把结果保存到这里。你可以随时移除授权。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          WidgetUtils.primaryButton(
                            text: '选择文件夹',
                            onPressed: _busy ? null : () => _choose(),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: folders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final location = [
                          folder['source'] as String,
                          folder['path'] as String,
                        ].where((s) => s.isNotEmpty).join(' · ');
                        final status = folder['readable'] != true
                            ? '需重新授权'
                            : folder['writable'] == true
                            ? '可读写'
                            : '只读';
                        return Material(
                          color: settingsFieldColor(context),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _busy ? null : () => _open(folder),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 32,
                                    child: Center(
                                      child: FileToolIcon(
                                        type: FileToolIconType.folder,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder['name'] as String,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.4,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$location\n$status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.5,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '修改显示名称',
                                    onPressed: _busy
                                        ? null
                                        : () => _rename(folder),
                                    icon: ConversationMenuIcon(
                                      type: ConversationMenuIconType.rename,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '移除授权',
                                    onPressed: _busy
                                        ? null
                                        : () => _remove(folder),
                                    icon: ConversationMenuIcon(
                                      type: ConversationMenuIconType.delete,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.name});
  final String name;
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final _text = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: GlassSurface(
        radius: 28,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '修改显示名称',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '仅在 Aurai 中使用，不会重命名原文件夹。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _text,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: '文件夹名称',
                  counterText: '',
                  filled: true,
                  fillColor: dialogControlColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              WidgetUtils.primaryButton(
                text: '保存',
                height: 46,
                onPressed: _text.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, _text.text.trim()),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
