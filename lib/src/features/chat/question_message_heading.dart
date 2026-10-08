import 'package:flutter/material.dart';

import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'question_icon.dart';
import 'interactive_status_tag.dart';

class QuestionMessageHeading extends StatelessWidget {
  const QuestionMessageHeading({
    super.key,
    required this.title,
    required this.description,
    required this.multiple,
    required this.status,
    this.recipient,
    this.onOpenMember,
    this.trailing,
    this.pager,
    this.modeLabel,
    this.sheetHeader = false,
    this.senderHeading,
  });

  final String title, description, status;
  final bool multiple;
  final MessageSender? recipient;
  final ValueChanged<String>? onOpenMember;
  final Widget? trailing;
  final Widget? pager;
  final String? modeLabel;
  final bool sheetHeader;
  final Widget? senderHeading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showStatus = status.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: sheetHeader ? kMinInteractiveDimension : 0,
          ),
          child: Row(
            children: [
              const QuestionIcon(type: QuestionIconType.question),
              const SizedBox(width: 8),
              Text(
                '问题 · ${modeLabel ?? (multiple ? '多选' : '单选')}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              const Spacer(),
              if (pager != null) pager!,
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (senderHeading != null) ...[
          senderHeading!,
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (recipient case final person?) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: onOpenMember != null,
                  label: '查看${person.displayName}的资料',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenMember == null
                        ? null
                        : () => onOpenMember!(person.id),
                    child: Row(
                      children: [
                        MemberAvatar(sender: person, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            person.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: GlobalUI.highlightTextColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showStatus) ...[
                const SizedBox(width: 12),
                InteractiveStatusTag(
                  label: status,
                  highlighted: status == '待回答',
                ),
              ],
            ],
          ),
        ],
        if (recipient == null && showStatus) ...[
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
