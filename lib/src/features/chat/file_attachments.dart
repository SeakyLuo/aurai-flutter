import '../../app/glass_notice.dart';
import 'dart:math' as math;

import '../../domain/message_summary.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/message_file.dart';
import '../../platform/message_file_store.dart';
import 'file_type_icon.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

class FileAttachments extends StatelessWidget {
  const FileAttachments({super.key, required this.files, this.onRemove});
  final List<MessageFile> files;
  final ValueChanged<MessageFile>? onRemove;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: math.max(
      92,
      MediaQuery.textScalerOf(context).scale(14) * 1.3 * 2 +
          MediaQuery.textScalerOf(context).scale(12) * 1.3 +
          36,
    ),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(6),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => SizedBox(
        width: 242,
        child: FileAttachmentCard(
          file: files[index],
          onRemove: onRemove == null ? null : () => onRemove!(files[index]),
        ),
      ),
    ),
  );
}

class FileAttachmentCard extends StatelessWidget {
  const FileAttachmentCard({
    super.key,
    required this.file,
    this.onRemove,
    this.onOpen,
    this.title,
    this.vertical = false,
  });
  final bool vertical;
  final InlineSpan? title;
  final VoidCallback? onOpen;
  final MessageFile file;
  final VoidCallback? onRemove;
  String get _size => file.size < 1024
      ? '${file.size} B'
      : file.size < 1024 * 1024
      ? '${(file.size / 1024).toStringAsFixed(1)} KB'
      : '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB';
  Widget _labels(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: vertical
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text.rich(
        title ??
            TextSpan(
              text: file.isHtml
                  ? MessageSummary.htmlFileTitle(file.name)
                  : file.name,
            ),
        textAlign: vertical ? TextAlign.center : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, height: 1.3),
      ),
      const SizedBox(height: 4),
      Text(
        '${file.isHtml
            ? '小程序'
            : file.name.contains('.')
            ? file.name.split('.').last.toUpperCase()
            : '文件'} · $_size',
        textAlign: vertical ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        onOpen?.call();
        try {
          await MessageFileStore.open(file);
        } on PlatformException catch (error) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showGlassSnackBar(
              SnackBar(
                content: Text(error.message ?? '附件无法打开：${errorMessage(error)}'),
              ),
            );
        }
      },
      child: Padding(
        padding: vertical
            ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
            : const EdgeInsets.only(left: 12, top: 10, bottom: 10, right: 6),
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 32,
                        child: FittedBox(child: FileTypeIcon(file: file)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _labels(context),
                ],
              )
            : Row(
                children: [
                  FileTypeIcon(file: file),
                  const SizedBox(width: 10),
                  Expanded(child: _labels(context)),
                  if (onRemove != null)
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        tooltip: '移除附件',
                        onPressed: onRemove,
                        icon: const QuestionIcon(type: QuestionIconType.close),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );
}
