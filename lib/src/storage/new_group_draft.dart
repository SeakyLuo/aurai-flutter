import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ai_profile.dart';
import '../domain/message_sender.dart';

class NewGroupDraft {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'new_group_draft';
  static Future<void> _pending = Future.value();

  Future<
    ({
      String title,
      List<String> contacts,
      List<AiProfile> members,
      List<String> excluded,
    })
  >
  load() async {
    await _pending;
    final saved = await _preferences.getString(_key);
    if (saved == null)
      return (
        title: '',
        contacts: <String>[],
        members: <AiProfile>[],
        excluded: <String>[],
      );
    final data = jsonDecode(saved) as Map<String, dynamic>;
    return (
      title: data['title'] as String,
      excluded: (data['excluded'] as List? ?? const []).cast<String>(),
      contacts: (data['contacts'] as List).cast<String>(),
      members: [
        for (final item in data['members'] as List)
          AiProfile.fromRows(
            MessageSender.fromRow(
              (item['sender'] as Map).cast<String, Object?>(),
            ),
            (item['profile'] as Map).cast<String, Object?>(),
          ),
      ],
    );
  }

  Future<void> save(
    String title,
    List<String> contacts,
    List<AiProfile> members, {
    List<String> excluded = const [],
  }) {
    final data = jsonEncode({
      'title': title,
      'excluded': excluded,
      'contacts': contacts,
      'members': [
        for (final ai in members)
          {
            'sender': {
              'id': ai.sender.id,
              'name': ai.sender.name,
              'kind': ai.sender.kind.name,
              'avatar_icon': ai.sender.avatarIcon,
              'avatar_color': ai.sender.avatarColor,
              'avatar_path': ai.sender.avatarPath,
              'archived': 0,
            },
            'profile': {
              'is_temporary': 1,
              'description': ai.description,
              'instructions': ai.instructions,
              'preferences': jsonEncode(ai.preferences.toJson()),
              'provider': ai.modelSelection?.provider.name,
              'model': ai.modelSelection?.model,
              'base_url': ai.modelSelection?.baseUrl,
              'created_at': ai.createdAt.microsecondsSinceEpoch,
              'updated_at': ai.updatedAt.microsecondsSinceEpoch,
            },
          },
      ],
    });
    return _enqueue(() => _preferences.setString(_key, data));
  }

  Future<void> clear() => _enqueue(() => _preferences.remove(_key));
  Future<void> _enqueue(Future<void> Function() operation) {
    final write = _pending.then((_) => operation());
    _pending = write.catchError((Object error) {});
    return write;
  }
}
