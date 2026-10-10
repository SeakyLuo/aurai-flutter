import 'package:flutter/material.dart';

import 'search_skeleton.dart';
import 'settings_appearance.dart';

class ConversationMessagesSkeleton extends StatelessWidget {
  const ConversationMessagesSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            View.of(context).padding.top / View.of(context).devicePixelRatio +
                SettingsAppBar.toolbarHeight +
                12,
            18,
            24,
          ),
          child: const SearchSkeleton(
            label: '正在加载消息',
            rowCount: 4,
            rowGap: 24,
            contentHeight: 64,
          ),
        ),
      ),
    ),
  );
}
