import 'package:flutter/material.dart';
import 'search_skeleton.dart';

class SpeechVoiceListSkeleton extends StatelessWidget {
  const SpeechVoiceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    physics: NeverScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: SearchSkeleton(
      label: '正在加载音色',
      avatarSize: 48,
      rowGap: 18,
      rowCount: 8,
    ),
  );
}
