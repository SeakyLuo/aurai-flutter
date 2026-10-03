import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_notice.dart';
import 'ui_action.dart';
import '../features/chat/copy_icon.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/settings_appearance.dart';

Future<void> showNoticeDetailsSheet(
  BuildContext context, {
  required InlineSpan text,
  required TextStyle style,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  elevation: 0,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: .55,
    minChildSize: .28,
    maxChildSize: .9,
    expand: false,
    builder: (context, scrollController) => SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60),
                  child: Text(
                    '提示详情',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SettingsGlassAction(
                      label: '关闭',
                      icon: Icons.close_rounded,
                      iconWidget: const QuestionIcon(
                        type: QuestionIconType.close,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SettingsGlassAction(
                      label: '复制完整内容',
                      icon: Icons.copy_rounded,
                      iconWidget: const CopyIcon(),
                      onPressed: () async {
                        final copied = await runUiAction(
                          context,
                          () => Clipboard.setData(
                            ClipboardData(text: text.toPlainText()),
                          ),
                        );
                        if (copied && context.mounted) {
                          ScaffoldMessenger.of(context).showToast(
                            const SnackBar(content: Text('已复制报错')),
                            kind: ToastKind.success,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  SelectableText.rich(TextSpan(style: style, children: [text])),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
