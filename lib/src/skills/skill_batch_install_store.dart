part of 'skill_store.dart';

typedef SkillInstallCandidate = ({
  MessageSender sender,
  bool installed,
  bool visible,
});

extension SkillBatchInstallOperations on SkillStore {
  bool _visibleFor(SavedSkill skill, String memberId) =>
      skill.visibility == 'public' ||
      skill.ownerId == memberId ||
      (skill.visibility == 'selected' && skill.visibleTo.contains(memberId));

  Future<List<SkillInstallCandidate>> groupInstallCandidates(
    String skillId,
    String groupId,
  ) async {
    final skill = readId(skillId);
    final rows = await Future.wait([
      _database.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND left_at IS NULL',
        whereArgs: [groupId],
      ),
      _database.query(
        'skill_installations',
        columns: ['owner_id'],
        where: 'skill_id = ?',
        whereArgs: [skillId],
      ),
    ]);
    final memberIds = rows[0].map((r) => r['sender_id'] as String).toSet();
    final installed = rows[1].map((r) => r['owner_id'] as String).toSet();
    return [
      for (final member in members)
        if (member.kind == MessageSenderKind.agent &&
            memberIds.contains(member.id))
          (
            sender: member,
            installed: installed.contains(member.id),
            visible: _visibleFor(skill, member.id),
          ),
    ];
  }

  Future<void> installForGroupMembers(
    String skillId,
    String groupId,
    Set<String> memberIds,
  ) => _enqueue(() async {
    final skill = readId(skillId);
    await _commit((txn) async {
      final rows = await txn.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND left_at IS NULL',
        whereArgs: [groupId],
      );
      final currentIds = rows.map((r) => r['sender_id'] as String).toSet();
      final agentIds = members
          .where((m) => m.kind == MessageSenderKind.agent)
          .map((m) => m.id)
          .toSet();
      if (memberIds.any(
        (id) => !currentIds.contains(id) || !agentIds.contains(id),
      )) {
        throw StateError('所选 AI 已不在群内，请重新选择');
      }
      if (memberIds.any((id) => !_visibleFor(skill, id))) {
        throw StateError('技能可见范围已变化，所选 AI 无法安装');
      }
      final batch = txn.batch();
      for (final id in memberIds) {
        batch.insert('skill_installations', {
          'skill_id': skill.id,
          'owner_id': id,
          'enabled': 1,
          'approved_revision': skill.revision,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  });
}
