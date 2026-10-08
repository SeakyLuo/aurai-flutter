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
            child: MemberAvatar(sender: person, size: 24),
          ),
        ),
        const Text('：', style: TextStyle(fontSize: 15, height: 1.5)),
        Expanded(child: child),
      ],
    );
  }
}
