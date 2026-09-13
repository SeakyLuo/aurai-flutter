import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../storage/attachment_search.dart';
import 'search_attachment_tile.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

class SearchLandingContent extends StatelessWidget {
  const SearchLandingContent({
    super.key,
    required this.files,
    required this.history,
    required this.onSearch,
    required this.onRemove,
    required this.onClear,
  });
  final List<AttachmentSearchResult> files;
  final List<String> history;
  final ValueChanged<String> onSearch, onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files.isNotEmpty) ...[
          const Text('最近的文件', style: titleStyle),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min((constraints.maxWidth - 12) / 2, 144.0);
              return SizedBox(
                height: size,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: size,
                    child: SearchAttachmentTile(
                      result: files[index],
                      compact: true,
                      gallery: files
                          .where((file) => file.image != null)
                          .map((file) => file.image!)
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        if (history.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: Text('最近搜索', style: titleStyle)),
              TextButton(
                onPressed: onClear,
                child: Text(
                  '清空',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          for (final query in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: settingsFieldColor(context),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSearch(query),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          child: Row(
                            children: [
                              const SizedBox.square(
                                dimension: 18,
                                child: FittedBox(
                                  child: SidebarActionIcon(
                                    type: SidebarActionIconType.search,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  query,
                                  style: const TextStyle(fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '删除搜索记录',
                      onPressed: () => onRemove(query),
                      icon: const SizedBox.square(
                        dimension: 18,
                        child: QuestionIcon(type: QuestionIconType.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
