part of 'chat_page.dart';

extension _ChatGroupNavigation on _ChatPageState {
  Widget _groupIntroduction(
    List<ChatTimelineEntry> timeline,
    double top,
    double bottom,
  ) => ListView(
    key: ValueKey('introduction:$_conversationId'),
    primary: false,
    padding: EdgeInsets.only(top: top, bottom: bottom + 16),
    children: [for (final entry in timeline) entry.builder(context)],
  );
}
