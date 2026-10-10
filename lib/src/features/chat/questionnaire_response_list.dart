import 'package:flutter/material.dart';

import '../../domain/interactive_message.dart';
import '../../domain/interactive_questionnaire.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'message_time.dart';
import 'settings_icon.dart';
import 'vote_participant_avatars.dart';

class QuestionnaireResponseList extends StatelessWidget {
  const QuestionnaireResponseList({
    super.key,
    required this.card,
    required this.viewerId,
    required this.members,
    this.onParticipant,
    this.onShowAll,
    this.compact = false,
  });
  final InteractiveMessage card;
  final String viewerId;
  final Map<String, MessageSender> members;
  final ValueChanged<String>? onParticipant;
  final VoidCallback? onShowAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = card.snapshotView != null
        ? card.snapshotView!['submissions'] is Map
        : card.visible('visibility', actor: viewerId);
    final choices = card.snapshotView != null
        ? {
            for (final entry
                in (card.snapshotView!['submissions'] as Map? ?? const {})
                    .entries)
              entry.key as String: Map<String, Object?>.from(
                entry.value as Map,
              ),
          }
        : card.choices;
    final own = card.snapshotView?['self'] as Map? ?? card.choices[viewerId];
    final entries = visible
        ? choices.entries.toList()
        : own == null
        ? <MapEntry<String, Map<String, Object?>>>[]
        : [MapEntry(viewerId, Map<String, Object?>.from(own))];
    int submittedAt(MapEntry<String, Map<String, Object?>> entry) =>
        (card.snapshotView == null
                ? card.participants[entry.key]!['updatedAt']
                : entry.value['updatedAt'])
            as int;
    entries.sort((a, b) => submittedAt(b).compareTo(submittedAt(a)));
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    if (compact) {
      return VoteParticipantAvatars(
        people: entries.map(_sender).toList(),
        onOpenMember: onParticipant,
        onShowAll: onShowAll,
        participantLabel: '填写人',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '填写人',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (!visible) ...[
          Text(
            questionnaireHiddenAnswersText(card, viewerId),
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          if (entries.isNotEmpty) const SizedBox(height: 8),
        ],
        if (visible && entries.isEmpty)
          Text('还没有人填写', style: TextStyle(color: secondary)),
        for (final entry in entries)
          InkWell(
            onTap: onParticipant == null
                ? null
                : () => onParticipant!(entry.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemberAvatar(sender: _sender(entry), size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key == MessageSender.localUser.id
                              ? '我'
                              : entry.value['name'] as String,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          messageTime(
                            DateTime.fromMicrosecondsSinceEpoch(
                              submittedAt(entry),
                            ),
                          ),
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ],
                    ),
                  ),
                  if (onParticipant != null)
                    const SettingsIcon(type: SettingsIconType.chevronDown),
                ],
              ),
            ),
          ),
      ],
    );
  }

  MessageSender _sender(MapEntry<String, Map<String, Object?>> entry) =>
      members[entry.key] ??
      (entry.key == MessageSender.localUser.id
          ? MessageSender.localUser
          : MessageSender(
              id: entry.key,
              name: entry.value['name'] as String,
              kind: MessageSenderKind.agent,
            ));
}
