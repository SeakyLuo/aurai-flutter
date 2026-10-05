import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

class TaskNodeDescription extends StatelessWidget {
  const TaskNodeDescription({
    super.key,
    required this.title,
    required this.description,
    required this.width,
  });
  final String title, description;
  final double width;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: description,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 4,
    )..layout(maxWidth: width);
    final overflow = painter.didExceedMaxLines;
    painter.dispose();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          description,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        if (overflow)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: GlobalUI.highlightTextColor(context),
            ),
            onPressed: () => _open(context),
            child: const Text('查看详情'),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) => showModalBottomSheet<void>(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SelectableText(
                  description,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
