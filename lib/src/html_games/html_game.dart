import 'dart:convert';
import 'dart:typed_data';

/// Intentionally not exposed to AI until the HTML message rollout is enabled.
abstract final class HtmlGameFeature {
  static const enabled = false;
}

class HtmlGameCard {
  const HtmlGameCard({
    required this.title,
    this.preview,
    this.width,
    this.height = 320,
    this.measuredWidth,
    this.measuredHeight,
    this.measuredScale,
    this.measuredVersion,
    this.version = 0,
    this.status = 'active',
    this.canRetry = false,
    this.displayMode = 'hybrid',
    this.backgroundMode = 'message',
  });
  final double? measuredWidth, measuredHeight, measuredScale;
  final int? measuredVersion;
  final String displayMode;
  final String backgroundMode;
  final String title;
  final Uint8List? preview;
  final int? width;
  final int height;
  final int version;
  final String status;
  final bool canRetry;
  factory HtmlGameCard.fromRow(Map<String, Object?> row) => HtmlGameCard(
    displayMode: row['display_mode'] as String,
    backgroundMode: row['background_mode'] as String,
    title: row['title'] as String,
    preview: row['preview'] as Uint8List?,
    measuredWidth: (row['measured_width'] as num?)?.toDouble(),
    measuredHeight: (row['measured_height'] as num?)?.toDouble(),
    measuredScale: (row['measured_scale'] as num?)?.toDouble(),
    measuredVersion: row['measured_version'] as int?,
    width: row['display_width'] as int?,
    height: row['display_height'] as int,
    version: row['version'] as int,
    status: row['status'] as String,
    canRetry: row['retry_available'] == 1,
  );
}

class HtmlGame {
  const HtmlGame({
    required this.messageId,
    required this.conversationId,
    required this.creatorId,
    required this.title,
    required this.html,
    required this.state,
    required this.version,
    required this.participants,
    required this.status,
    required this.turnSenderId,
    this.preview,
    required this.width,
    required this.height,
    required this.canRetry,
    this.stateful = false,
    this.backgroundMode = 'message',
  });
  final bool stateful;
  final String backgroundMode;
  final int? width;
  final int height;
  final bool canRetry;
  final String messageId;
  final String conversationId;
  final String creatorId;
  final String title;
  final String html;
  final Map<String, Object?> state;
  final int version;
  final List<String> participants;
  final String status;
  final String? turnSenderId;
  final Uint8List? preview;

  factory HtmlGame.fromRow(Map<String, Object?> row) => HtmlGame(
    messageId: row['message_id'] as String,
    stateful: row['stateful'] == 1,
    backgroundMode: row['background_mode'] as String,
    width: row['display_width'] as int?,
    height: row['display_height'] as int,
    canRetry: row['retry_available'] == 1,
    conversationId: row['conversation_id'] as String,
    creatorId: row['creator_id'] as String,
    title: row['title'] as String,
    html: row['html'] as String,
    state: (jsonDecode(row['state_json'] as String) as Map)
        .cast<String, Object?>(),
    version: row['version'] as int,
    participants: List<String>.from(
      jsonDecode(row['participants_json'] as String) as List,
    ),
    status: row['status'] as String,
    turnSenderId: row['turn_sender_id'] as String?,
    preview: row['preview'] as Uint8List?,
  );

  Map<String, Object?> snapshot() => {
    'messageId': messageId,
    'backgroundMode': backgroundMode,
    'width': width,
    'height': height,
    'title': title,
    'state': state,
    'version': version,
    'participants': participants,
    'status': status,
    'turnSenderId': turnSenderId,
  };
}
