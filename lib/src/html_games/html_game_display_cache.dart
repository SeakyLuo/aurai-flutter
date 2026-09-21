import '../domain/agent_models.dart';
import 'html_game.dart';
import 'html_game_store.dart';

/// Small display-only cache. Tool reads continue to use the canonical store.
class HtmlGameDisplayCache {
  static final _games = <String, HtmlGame>{};
  static final _content =
      <
        String,
        ({String html, String background, bool stateful, String token})
      >{};

  static void invalidate(String messageId) => _games.remove(messageId);

  static void releaseContent() {
    _games.clear();
  }

  static Future<HtmlGame> load(
    HtmlGameStore store,
    String conversationId,
    String messageId,
  ) async {
    final rows = await store.database.rawQuery(
      "SELECT version FROM html_games WHERE message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      [messageId, conversationId],
    );
    if (rows.isEmpty) {
      _games.remove(messageId);
      throw StateError('HTML 消息已删除或撤回');
    }
    final cached = _games.remove(messageId);
    final game = cached != null && cached.version == rows.single['version']
        ? cached
        : await store.load(conversationId, messageId);
    _games[messageId] = game;
    if (_games.length > 6) _games.remove(_games.keys.first);
    return game;
  }

  static String identity(HtmlGame game) {
    final old = _content.remove(game.messageId);
    final token =
        old != null &&
            old.html == game.html &&
            old.background == game.backgroundMode &&
            old.stateful == game.stateful
        ? old.token
        : newMessageId();
    _content[game.messageId] = (
      html: game.html,
      background: game.backgroundMode,
      stateful: game.stateful,
      token: token,
    );
    if (_content.length > 8) _content.remove(_content.keys.first);
    return token;
  }
}
