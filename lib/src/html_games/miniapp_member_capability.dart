import 'package:sqflite/sqflite.dart';
import '../storage/group_member_details.dart';

class MiniappMemberCapability {
  const MiniappMemberCapability();

  Future<void> setNicknames(
    DatabaseExecutor db,
    String conversationId, {
    required String actorId,
    required Map<String, String> nicknames,
  }) => GroupMemberDetailsStore.setNicknames(
    db,
    conversationId,
    actorId: actorId,
    nicknames: nicknames,
  );
}
