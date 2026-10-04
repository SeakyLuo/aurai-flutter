import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'html_game.dart';
import 'html_store.dart';

/// Small display-only cache. Tool reads continue to use the canonical store.
class HtmlGameDisplayCache {
  static final _games = <String, HtmlGame>{};

  static void invalidate(String messageId) => _games.remove(messageId);

  static void releaseContent() {
    _games.clear();
  }

  static Future<HtmlGame> load(
    HtmlStore store,
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

  // The native page outlives the display cache and list entries. Its identity
  // must remain stable when ordinary messages rebuild or move those entries.
  static String identity(HtmlGame game) => sha256
      .convert(
        utf8.encode(
          jsonEncode([game.html, game.backgroundMode, game.stateful]),
        ),
      )
      .toString();
}
