import 'package:flutter/material.dart';

import 'search_skeleton.dart';

class ModelListSkeleton extends StatelessWidget {
  const ModelListSkeleton({super.key, required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: padding,
    child: const SearchSkeleton(
      label: '正在加载模型',
      avatarSize: 24,
      rowGap: 24,
      rowCount: 8,
    ),
  );
}
