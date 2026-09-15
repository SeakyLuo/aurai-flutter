import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/agent_models.dart';

/// Local recovery content is kept outside message history and model context.
class RecalledMessageDrafts {
  static final instance = RecalledMessageDrafts();
  final _preferences = SharedPreferencesAsync();
  late final Future<Map<String, dynamic>> entries = _load();
  Future<void> _pending = Future.value();

  Future<Map<String, dynamic>> _load() async {
    final raw = await _preferences.getString('recalled_message_drafts');
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> save(AgentMessage message) {
    final write = _pending.then((_) async {
      final data = await entries;
      data[message.id] = {
        'text': message.text,
        'images': [
          for (final image in message.images)
            {...image.toJson(), 'path': image.path},
        ],
        'files': [
          for (final file in message.files)
            {...file.toJson(), 'path': file.path},
        ],
      };
      while (data.length > 100) {
        data.remove(data.keys.first);
      }
      await _preferences.setString('recalled_message_drafts', jsonEncode(data));
    });
    _pending = write.catchError((Object error) {});
    return write;
  }
}
