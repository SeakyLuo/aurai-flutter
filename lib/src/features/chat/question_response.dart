import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';

/// Identify the answer only where the conversation needs an explicit recipient.
class QuestionResponse extends StatelessWidget {
  const QuestionResponse({
    super.key,
    required this.child,
    this.recipient,
    this.onOpenMember,
  });
  final Widget child;
  final MessageSender? recipient;
  final ValueChanged<String>? onOpenMember;

  @override
  Widget build(BuildContext context) {
    final person = recipient;
    if (person == null) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '${person.displayName}的回答',
          button: onOpenMember != null,
          child: GestureDetector(
            onTap: onOpenMember == null ? null : () => onOpenMember!(person.id),
            child: SizedBox(
              height: (MediaQuery.textScalerOf(context).scale(15) * 1.5).clamp(
                20.0,
                double.infinity,
              ),
              child: Center(child: MemberAvatar(sender: person, size: 20)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}
