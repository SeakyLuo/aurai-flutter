import '../../app/glass_notice.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/error_message.dart';
import 'attachment_action_icon.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'data_management_dialogs.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  static const _channel = MethodChannel(
    'com.haiskynology.aurai/data_management',
  );
  Map<Object?, Object?>? _usage;
  String? _busy = 'usage';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUsage();
      if (mounted) setState(() => _busy = null);
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadUsage() async {
    try {
      final usage = await _channel.invokeMapMethod<Object?, Object?>('usage');
      if (mounted) setState(() => _usage = usage);
    } on Object catch (error) {
      _notice(errorMessage(error));
    }
  }

  bool _available() {
    final controller = widget.controller;
    if (controller.addingImages || controller.changingConversation) {
      _notice('请等待附件处理或会话切换完成');
      return false;
    }
    return true;
  }

  Future<void> _backup(bool export) async {
    if (_busy != null || !_available()) return;
    // Hold the page while the system picker is open too.
    setState(() => _busy = export ? 'export' : 'import');
    bool staged = false;
    bool committed = false;
    try {
      await widget.controller.saveDraft();
      final info = await _channel.invokeMapMethod<Object?, Object?>(
        export ? 'export' : 'inspectImport',
      );
      if (info == null) return;
      if (export) {
        final missing = info['missingFiles'] as int;
        _notice(missing == 0 ? '备份已导出' : '备份已导出；有 $missing 个原文件此前已丢失，未能包含在备份中');
        await _loadUsage();
        return;
      }
      staged = true;
      if (!mounted) return;
      final missing = info['missingFiles'] as int;
      final confirmed = await confirmDataAction(
        context,
        title: '恢复此备份？',
        description:
            '${_date(info['createdAt'] as int)}\n'
            '${info['conversations']} 个会话 · ${info['messages']} 条消息\n'
            '${info['friends']} 位朋友 · ${info['memories']} 条记忆 · ${info['skills']} 个技能\n'
            '${info['hasModelKeys'] == true ? '包含模型设置与密钥' : '不包含模型密钥'}'
            '${missing > 0 ? '\n有 $missing 个原文件在备份前已丢失' : ''}\n\n'
            '这会结束正在进行的回复，并替换当前全部数据，不会合并。导入后 App 将退出，重新打开即可完成恢复。',
        action: '替换数据并退出',
        destructive: true,
      );
      if (!confirmed || !mounted || !_available()) return;
      await _channel.invokeMethod<void>('commitImport');
      committed = true;
    } on Object catch (error) {
      _notice(errorMessage(error));
    } finally {
      if (staged && !committed) {
        try {
          await _channel.invokeMethod<void>('discardImport');
        } on Object catch (error) {
          _notice(errorMessage(error));
        }
      }
      if (mounted && !committed) setState(() => _busy = null);
    }
  }

  Future<void> _clearCache() async {
    if (_busy != null || !_available()) return;
    setState(() => _busy = 'cache');
    try {
      final confirmed = await confirmDataAction(
        context,
        title: '清理缓存？',
        description: '仅清理可重新生成的临时文件。聊天记录、图片原件、附件、朋友、记忆和模型设置都会保留。',
        action: '清理缓存',
      );
      if (!confirmed || !mounted || !_available()) return;
      final usage = await _channel.invokeMapMethod<Object?, Object?>(
        'clearCache',
      );
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) setState(() => _usage = usage);
      _notice('缓存已清理');
    } on Object catch (error) {
      _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _date(int value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _row({
    required String keyName,
    required Widget icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: icon,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: _busy == keyName
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SettingsIcon(type: SettingsIconType.chevron),
        onTap: _busy != null ? null : onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    return PopScope(
      canPop: _busy == null,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          gradientBackground: true,
          title: '数据管理',
          onBack: _busy == null ? () => Navigator.maybePop(context) : null,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  View.of(context).padding.top /
                          View.of(context).devicePixelRatio +
                      76 +
                      16,
                  16,
                  16,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    child: Text(
                      usage == null
                          ? '本地数据'
                          : '本地数据 · ${_size(usage['dataBytes'] as int)}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  _row(
                    keyName: 'export',
                    icon: Transform.rotate(
                      angle: math.pi,
                      child: const AttachmentActionIcon(
                        type: AttachmentActionIconType.download,
                      ),
                    ),
                    title: '导出备份',
                    subtitle: '保存聊天、原始附件、设置和模型密钥',
                    onTap: () => _backup(true),
                  ),
                  _row(
                    keyName: 'import',
                    icon: const AttachmentActionIcon(
                      type: AttachmentActionIconType.download,
                    ),
                    title: '导入备份',
                    subtitle: '从备份文件恢复，替换当前数据',
                    onTap: () => _backup(false),
                  ),
                  if (usage != null && (usage['lastExportAt'] as int) > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                      child: Text(
                        '上次导出 · ${_date(usage['lastExportAt'] as int)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _row(
                    keyName: 'cache',
                    icon: ConversationMenuIcon(
                      color: Theme.of(context).colorScheme.onSurface,
                      type: ConversationMenuIconType.delete,
                    ),
                    title: '清理缓存',
                    subtitle: usage == null
                        ? '仅清理临时文件，保留聊天与附件'
                        : '${_size(usage['cacheBytes'] as int)} · 不影响聊天与附件',
                    onTap: _clearCache,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
