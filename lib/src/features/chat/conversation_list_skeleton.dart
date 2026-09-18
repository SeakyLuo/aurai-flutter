import 'package:flutter/material.dart';

import 'search_skeleton.dart';

class ConversationListSkeleton extends StatelessWidget {
  const ConversationListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          24,
          View.of(context).padding.top / View.of(context).devicePixelRatio +
              76 +
              20,
          24,
          24,
        ),
        child: const SearchSkeleton(label: '正在加载会话', rowGap: 32),
      ),
    ),
  );
}
