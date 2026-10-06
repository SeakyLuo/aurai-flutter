import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/avatar_style.dart';
import 'group_chat_store.dart';
import 'group_system_notice.dart';

class GroupAvatarStore {
  GroupAvatarStore(this.groups);
  final GroupChatStore groups;
  static final styles = ValueNotifier<Map<String, AvatarStyle>>({});

  static Future<void> load(Database db, List<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await db.query(
      'conversations',
      columns: ['id', 'group_avatar'],
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final next = {...styles.value};
    for (final row in rows) {
      final id = row['id'] as String;
      final value = row['group_avatar'] as String?;
      if (value == null) {
        next.remove(id);
      } else {
        next[id] = AvatarStyle.fromRow(
          jsonDecode(value) as Map<String, dynamic>,
        );
      }
    }
    styles.value = next;
  }

  Future<void> save(
    String id,
    AvatarStyle? style, {
    required String actorId,
  }) async {
    final value = style == null ? null : jsonEncode(style.columns);
    final notice = await groups.database.transaction((txn) async {
      await groups.requireManager(txn, id, actorId);
      final current = (await txn.query(
        'conversations',
        columns: ['group_avatar'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).single;
      if (current['group_avatar'] == value) return null;
      final actor = (await txn.query(
        'message_senders',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [actorId],
        limit: 1,
      )).single;
      await txn.update(
        'conversations',
        {'group_avatar': value},
        where: 'id = ?',
        whereArgs: [id],
      );
      return writeGroupNotice(txn, id, '${actor['name']}更新了群头像');
    });
    final next = {...styles.value};
    if (style == null) {
      next.remove(id);
    } else {
      next[id] = style;
    }
    styles.value = next;
    if (notice != null) await groups.onSystemNotice?.call(id, notice);
  }
}
