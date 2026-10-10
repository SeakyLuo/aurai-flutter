import '../domain/interactive_message.dart';
import 'miniapp_capability_protocol.dart';

/// Only host-counted aggregates cross the anonymous card/program boundary.
Map<String, Object?> anonymousProgramVote(
  InteractiveMessage card,
  String cardId,
  Object? context,
) => {
  'context': context,
  'anonymous': true,
  'cardId': cardId,
  'round': card.engine.round,
  'completed': card.completed,
  'closed': card.closed,
  'submittedCount': card.choices.length,
  if (card.interaction['actors'] case final List actors)
    'eligibleCount': actors.length,
  'summary': card.summary,
};

/// Anonymous callbacks cannot borrow privileges from the hidden respondent.
void validateAnonymousVoteEffects(MiniappCapabilityCalls calls) {
  if (calls.contextInstructions != null ||
      calls.hostSenderId != null ||
      calls.pinMessage ||
      calls.markMessage ||
      calls.nicknames.isNotEmpty ||
      calls.submissions.isNotEmpty) {
    throw StateError('匿名投票回调不能执行需要操作人身份的操作：代投、修改群名片、置顶、标记或压缩上下文');
  }
}
