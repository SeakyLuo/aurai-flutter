import '../domain/message_file.dart';
import '../domain/message_sender.dart';
import '../domain/message_quote.dart';
import '../domain/draft_mention.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/message_image.dart';
import '../features/chat/conversation.dart';

class NewConversationDraft {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'new_conversation_draft';
  Future<void> _pending = Future.value();

  String _senderKey(String senderId) =>
      senderId == MessageSender.aurai.id ? _key : '${_key}_$senderId';

  Future<Conversation> load(String imageDirectory, {String? senderId}) async {
    final owner = senderId ?? MessageSender.aurai.id;
    final saved = await _preferences.getString(_senderKey(owner));
    if (saved == null) return Conversation.empty()..defaultSenderId = owner;
    final data = (jsonDecode(saved) as Map).cast<String, Object?>();
    return Conversation(
        id: data['id']! as String,
        createdAt: DateTime.parse(data['createdAt']! as String),
      )
      ..defaultSenderId = owner
      ..storedTitle = data['title'] as String?
      ..draft = data['text']! as String
      ..draftQuote = data['quote'] == null
          ? null
          : MessageQuote.fromJson(
              (data['quote'] as Map).cast<String, Object?>(),
            )
      ..draftMentions.addAll(
        (data['mentions'] as List? ?? const []).map(
          (value) =>
              DraftMention.fromJson((value as Map).cast<String, dynamic>()),
        ),
      )
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
      'quote': conversation.draftQuote?.toJson(),
      'mentions': conversation.draftMentions
          .map((item) => item.toJson())
          .toList(),
      'files': conversation.draftFiles.map((file) => file.toJson()).toList(),
      'images': conversation.draftImages
          .map((image) => image.toJson())
          .toList(),
    });
    final key = _senderKey(conversation.defaultSenderId);
    return _enqueue(() => _preferences.setString(key, data));
  }

  Future<void> clear({String? senderId}) => _enqueue(
    () => _preferences.remove(_senderKey(senderId ?? MessageSender.aurai.id)),
  );

  Future<void> _enqueue(Future<void> Function() operation) {
    final write = _pending.then((_) => operation());
    _pending = write.catchError((Object error) {});
    return write;
  }
}
