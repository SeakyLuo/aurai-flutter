import '../domain/message_file.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/message_image.dart';
import '../features/chat/conversation.dart';

class NewConversationDraft {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'new_conversation_draft';
  Future<void> _pending = Future.value();

  Future<Conversation> load(String imageDirectory) async {
    final saved = await _preferences.getString(_key);
    if (saved == null) return Conversation.empty();
    final data = (jsonDecode(saved) as Map).cast<String, Object?>();
    return Conversation(
        id: data['id']! as String,
        createdAt: DateTime.parse(data['createdAt']! as String),
      )
      ..storedTitle = data['title'] as String?
      ..draft = data['text']! as String
      ..draftFiles.addAll(
        (data['files'] as List? ?? const []).map(
          (file) => MessageFile.fromJson(
            (file as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        ),
      )
      ..draftImages.addAll(
        (data['images']! as List).map(
          (image) => MessageImage.fromJson(
            (image as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        ),
      );
  }

  Future<void> save(Conversation conversation) {
    final data = jsonEncode({
      'id': conversation.id,
      'createdAt': conversation.createdAt.toIso8601String(),
      'text': conversation.draft,
      'title': conversation.storedTitle,
      'files': conversation.draftFiles.map((file) => file.toJson()).toList(),
      'images': conversation.draftImages
          .map((image) => image.toJson())
          .toList(),
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
