import 'package:flutter/material.dart';
import 'message_action.dart';

Future<MessageAction?> showQuickReplyPicker(
  BuildContext context, {
  String? selectedKey,
}) => showModalBottomSheet<MessageAction>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _QuickReplyPicker(selectedKey: selectedKey),
);

class _QuickReplyPicker extends StatelessWidget {
  const _QuickReplyPicker({this.selectedKey});
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  runSpacing: 8,
                  children: [
                    for (final (action, emoji, label, key) in quickReplyOptions)
                      SizedBox(
                        width: constraints.maxWidth / 5,
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.pop(context, action),
                            child: Container(
                              alignment: Alignment.center,
                              height: 60,
                              decoration: BoxDecoration(
                                color: selectedKey == key
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
