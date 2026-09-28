import 'package:flutter/material.dart';

import '../../domain/workspace_file_changes.dart';
import '../../domain/line_change_count.dart';
import 'attachment_action_icon.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

class WorkspaceChangesView extends StatelessWidget {
  const WorkspaceChangesView({super.key, required this.changes});
  final WorkspaceFileChanges changes;

  Future<void> showAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => FractionallySizedBox(
      heightFactor: .75,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '文件变更（${changes.files.length}）',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            if (changes.lineCount case final count?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkspaceLineCounts(
                  count,
                  partial: !changes.allLinesCounted || !changes.complete,
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: changes.files.length,
                itemBuilder: (_, index) =>
                    _FileChangeRow(changes.files[index], expanded: true),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (changes.files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '已编辑 ${changes.files.length} 个文件${changes.complete ? '' : '（部分）'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              if (changes.lineCount case final count?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: WorkspaceLineCounts(
                    count,
                    partial: !changes.allLinesCounted || !changes.complete,
                  ),
                ),
              for (final file in changes.files.take(3)) _FileChangeRow(file),
              if (changes.files.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showAll(context),
                    child: Text('查看全部 ${changes.files.length} 个文件'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileChangeRow extends StatelessWidget {
  const _FileChangeRow(this.file, {this.expanded = false});
  final WorkspaceFileChange file;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = file.after == null ? colors.error : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AttachmentActionIcon(
            type: AttachmentActionIconType.file,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.displayPath ?? file.path,
              maxLines: expanded ? null : 2,
              overflow: expanded ? null : TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(file.label, style: TextStyle(fontSize: 12, color: color)),
              if (file.lineCount case final count?) ...[
                const SizedBox(height: 4),
                WorkspaceLineCounts(count),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class WorkspaceLineCounts extends StatelessWidget {
  const WorkspaceLineCounts(this.count, {super.key, this.partial = false});
  final LineChangeCount count;
  final bool partial;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        if (partial) const TextSpan(text: '已统计文本 '),
        TextSpan(
          text: '+${count.added}',
          style: const TextStyle(color: Color(0xff00ad8b)),
        ),
        const TextSpan(text: '  '),
        TextSpan(
          text: '−${count.removed}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ),
    semanticsLabel:
        '${partial ? '已统计文本，' : ''}新增 ${count.added} 行，删除 ${count.removed} 行',
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class WorkspaceFilePathText extends StatelessWidget {
  const WorkspaceFilePathText(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final separator = path.lastIndexOf('/');
    final prefix = separator < 0 ? '' : path.substring(0, separator + 1);
    final name = separator < 0 ? path : path.substring(separator + 1);
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          TextSpan(
            text: name,
            style: TextStyle(color: colors.onSurface),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }
}
