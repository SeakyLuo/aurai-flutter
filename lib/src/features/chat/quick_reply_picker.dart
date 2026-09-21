import 'package:flutter/material.dart';
import '../../domain/quick_reply_option.dart';
import 'quick_reply_groups.dart';

Future<QuickReplyOption?> showQuickReplyPicker(
  BuildContext context, {
  Set<String> selectedKeys = const {},
}) => showModalBottomSheet<QuickReplyOption>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _QuickReplyPicker(selectedKeys: selectedKeys),
);

class _QuickReplyPicker extends StatelessWidget {
  const _QuickReplyPicker({required this.selectedKeys});
  final Set<String> selectedKeys;

  @override
  Widget build(BuildContext context) {
    final options = quickReplyOptionsByKey;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final group in quickReplyGroups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      group.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      runSpacing: 8,
                      children: [
                        for (final option in group.value.map(
                          (key) => options[key]!,
                        ))
                          SizedBox(
                            width: constraints.maxWidth / 6,
                            child: Semantics(
                              label: option.emoji,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => Navigator.pop(context, option),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: selectedKeys.contains(option.key)
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : null,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    option.emoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
