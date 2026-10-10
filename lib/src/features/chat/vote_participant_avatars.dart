import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import 'member_avatar.dart';

class VoteParticipantAvatars extends StatelessWidget {
  const VoteParticipantAvatars({
    super.key,
    required this.people,
    this.onOpenMember,
    this.onShowAll,
    this.participantLabel = '投票者',
  });

  final List<MessageSender> people;
  final ValueChanged<String>? onOpenMember;
  final VoidCallback? onShowAll;
  final String participantLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const size = 32.0;
      const gap = 8.0;
      final slots = math.min(
        people.length,
        math.max(1, ((constraints.maxWidth + gap) / (size + gap)).floor()) * 2,
      );
      final overflow = people.length > slots;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var index = 0; index < slots; index++) ...[
            Builder(
              builder: (context) {
                final sender = people[index];
                final more = overflow && index == slots - 1;
                final label = more
                    ? '查看其余 ${people.length - slots + 1} 位$participantLabel'
                    : sender.displayName;
                return Tooltip(
                  message: label,
                  child: Semantics(
                    button: true,
                    label: label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(size / 2),
                      onTap: more
                          ? onShowAll
                          : onOpenMember == null
                          ? null
                          : () => onOpenMember!(sender.id),
                      child: Stack(
                        children: [
                          MemberAvatar(sender: sender, size: size),
                          if (more)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .48),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '+${people.length - slots + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      );
    },
  );
}
