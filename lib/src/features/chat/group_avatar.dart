import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.members, this.size = 48});
  final List<MessageSender> members;
  final double size;
  @override
  Widget build(BuildContext context) {
    final visible = members.take(9).toList();
    final columns = visible.length <= 4 ? 2 : 3;
    final cell = (size - 8 - (columns - 1) * 2) / columns;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(size * .26),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var start = 0; start < visible.length; start += columns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (
                    var i = start;
                    i < math.min(start + columns, visible.length);
                    i++
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: MemberAvatar(sender: visible[i], size: cell),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
