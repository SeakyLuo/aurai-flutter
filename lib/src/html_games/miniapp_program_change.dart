import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';
import 'html_game_session.dart';
import 'miniapp_program_store.dart';

class MiniappContextCompaction {
  const MiniappContextCompaction({
    required this.eventId,
    required this.instructions,
    required this.throughMessageId,
    required this.throughCreatedAt,
  });

  final String eventId, instructions, throughMessageId;
  final int throughCreatedAt;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'instructions': instructions,
    'throughMessageId': throughMessageId,
    'throughCreatedAt': throughCreatedAt,
  };

  factory MiniappContextCompaction.fromJson(Map json) =>
      MiniappContextCompaction(
        eventId: json['eventId'] as String,
        instructions: json['instructions'] as String,
        throughMessageId: json['throughMessageId'] as String,
        throughCreatedAt: json['throughCreatedAt'] as int,
      );
}

class MiniappProgramChange {
  MiniappProgramChange(this.conversationId, this.messageId);
  final String conversationId, messageId;
  final messages = <({AgentMessage message, bool wakeAi})>[];
  final cards = <String, InteractiveMessage>{};
  final replyStates = <String, bool>{};
  bool memberNamesChanged = false;
  String? pinActorId;
  String? markActorId;
  MiniappContextCompaction? contextCompaction;

  /// The application processes this effect after commit, before any AI wakes.
  static Future<bool> Function(MiniappProgramChange)? compactContext;

  Future<void> publish() async {
    if (contextCompaction != null && !await compactContext!(this)) return;
    HtmlGameSignals.changes.add(messageId);
    MiniappProgramStore.changes.add(this);
  }

  Map<String, Object?> toJson() => {
    'conversationId': conversationId,
    'messageId': messageId,
    'contextCompaction': contextCompaction!.toJson(),
    'messages': [
      for (final entry in messages)
        {'message': entry.message.toJson(), 'wakeAi': entry.wakeAi},
    ],
    'cards': {
      for (final entry in cards.entries)
        entry.key: entry.value.toJson(includeParticipants: true),
    },
    'replyStates': replyStates,
    'memberNamesChanged': memberNamesChanged,
    if (pinActorId != null) 'pinActorId': pinActorId,
    if (markActorId != null) 'markActorId': markActorId,
  };

  factory MiniappProgramChange.fromJson(
    Map json,
    Map<String, MessageSender> senders,
  ) {
    final change =
        MiniappProgramChange(
            json['conversationId'] as String,
            json['messageId'] as String,
          )
          ..contextCompaction = MiniappContextCompaction.fromJson(
            json['contextCompaction'] as Map,
          );
    for (final raw in json['messages'] as List) {
      final entry = raw as Map;
      change.messages.add((
        message: AgentMessage.fromJson(
          (entry['message'] as Map).cast<String, Object?>(),
          imageDirectory: '',
        ).withSender(senders[(entry['message'] as Map)['senderId']]),
        wakeAi: entry['wakeAi'] as bool,
      ));
    }
    change.cards.addAll({
      for (final entry in (json['cards'] as Map).entries)
        entry.key as String: InteractiveMessage.fromJson(
          (entry.value as Map).cast<String, Object?>(),
        ),
    });
    change.replyStates.addAll(
      (json['replyStates'] as Map).cast<String, bool>(),
    );
    change.memberNamesChanged = json['memberNamesChanged'] as bool;
    change.pinActorId = json['pinActorId'] as String?;
    change.markActorId = json['markActorId'] as String?;
    return change;
  }
}
