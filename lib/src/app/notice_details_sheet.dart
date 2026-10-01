import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/dialog_action_button.dart';
import '../features/chat/glass_surface.dart';

Future<void> showNoticeDetailsSheet(
  BuildContext context, {
  required InlineSpan text,
  required TextStyle style,
  SnackBarAction? action,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  elevation: 0,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .16),
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: .55,
    minChildSize: .28,
    maxChildSize: .9,
    expand: false,
    builder: (context, scrollController) => GlassSurface(
      radius: 28,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 18),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '提示详情',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    children: [
                      SelectableText.rich(
                        TextSpan(style: style, children: [text]),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    DialogActionButton(
                      text: '复制',
                      role: DialogActionRole.secondary,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: text.toPlainText()),
                        );
                      },
                    ),
                    if (action != null)
                      DialogActionButton(
                        text: action.label,
                        onPressed: () {
                          Navigator.pop(context);
                          action.onPressed();
                        },
                      ),
                    DialogActionButton(
                      text: '关闭',
                      role: DialogActionRole.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
