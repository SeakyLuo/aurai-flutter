import 'package:flutter/material.dart';
import '../../domain/quick_reply_option.dart';
import '../../storage/quick_reply_recents.dart';
import 'quick_reply_groups.dart';

Future<QuickReplyOption?> showQuickReplyPicker(
  BuildContext context, {
  Set<String> selectedKeys = const {},
}) async {
  final recent = await QuickReplyRecents.load();
  if (!context.mounted) return null;
  return showModalBottomSheet<QuickReplyOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _QuickReplyPicker(selectedKeys: selectedKeys, recent: recent),
  );
}

class _QuickReplyPicker extends StatelessWidget {
  const _QuickReplyPicker({required this.selectedKeys, required this.recent});
  final Set<String> selectedKeys;
  final List<String> recent;

  @override
  Widget build(BuildContext context) {
    final options = quickReplyOptionsByKey;
    final visibleKeys = recentQuickReplyKeys(recent, 12);
    final groups = {
      '最近使用': visibleKeys,
      for (final group in quickReplyGroups.entries)
        if (group.key != '常用反馈') group.key: group.value,
    };
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
                for (final group in groups.entries) ...[
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
