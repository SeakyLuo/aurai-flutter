import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/app_dialog.dart';
import '../features/chat/dialog_action_button.dart';
import 'miniapp_library_store.dart';

class MiniappPublishDialog extends StatefulWidget {
  const MiniappPublishDialog({
    super.key,
    required this.entry,
    required this.store,
  });
  final MiniappEntry entry;
  final MiniappLibraryStore store;

  @override
  State<MiniappPublishDialog> createState() => _MiniappPublishDialogState();
}

class _MiniappPublishDialogState extends State<MiniappPublishDialog> {
  late final _title = TextEditingController(
    text: widget.entry.publishedTitle ?? widget.entry.title,
  );
  late final _description = TextEditingController(
    text: widget.entry.description,
  );
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.publish(widget.entry, _title.text, _description.text);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      maxWidth: 380,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry.revision == 0 ? '发布小程序' : '发布新版本',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '简介'),
            ),
            const SizedBox(height: 12),
            Text(
              '发布当前版本，不包含聊天记录和存档。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DialogActionButton(
                    text: '取消',
                    role: DialogActionRole.secondary,
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DialogActionButton(
                    text: '发布',
                    loading: _saving,
                    onPressed: _saving ? null : _publish,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
