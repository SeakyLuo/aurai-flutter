import 'app_bottom_sheet.dart';
import '../../domain/message_summary.dart';
import 'app_sheet_body.dart';
import 'package:flutter/material.dart';
import 'settings_icon.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

class TaskNodeDescription extends StatelessWidget {
  const TaskNodeDescription({
    super.key,
    required this.title,
    required this.description,
    required this.width,
    required this.titleStyle,
  });
  final String title, description;
  final double width;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final preview = MessageSummary.preview(description, limit: 1024);
    final style = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: preview,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 4,
    )..layout(maxWidth: width);
    final overflow = description.length > 1024 || painter.didExceedMaxLines;
    painter.dispose();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: titleStyle)),
            if (overflow) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 12, height: 1.5),
                  minimumSize: const Size(0, 20),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _open(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('查看详情'),
                    const SizedBox(width: 4),
                    SizedBox.square(
                      dimension: 14,
                      child: FittedBox(
                        child: SettingsIcon(
                          type: SettingsIconType.chevron,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context) => showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: AppSheetBody(
          shrinkWrap: true,
          headerExtent: 80,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
            child: SelectableText(
              description,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ),
      ),
    ),
  );
}
