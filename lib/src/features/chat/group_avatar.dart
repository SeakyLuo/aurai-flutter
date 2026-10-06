import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'profile_avatar.dart';
import '../../storage/group_avatar_store.dart';
import 'settings_appearance.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.groupId,
    required this.members,
    this.size = 48,
  });
  final String groupId;
  final List<MessageSender> members;
  final double size;
  static double memberSize(double size, int count) =>
      count <= 3 ? size : size / 2;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: GroupAvatarStore.styles,
    builder: (context, styles, _) {
      final style = styles[groupId];
      return style == null
          ? _members(context)
          : ProfileAvatar(style: style, name: '', size: size);
    },
  );

  Widget _members(BuildContext context) {
    final visible = members.take(4).toList();
    final half = size / 2;
    final cells = switch (visible.length) {
      0 => <Rect>[],
      1 => [Rect.fromLTWH(0, 0, size, size)],
      2 => [
        Rect.fromLTWH(0, 0, half, size),
        Rect.fromLTWH(half, 0, half, size),
      ],
      3 => [
        Rect.fromLTWH(0, 0, half, size),
        Rect.fromLTWH(half, 0, half, half),
        Rect.fromLTWH(half, half, half, half),
      ],
      _ => [
        Rect.fromLTWH(0, 0, half, half),
        Rect.fromLTWH(half, 0, half, half),
        Rect.fromLTWH(0, half, half, half),
        Rect.fromLTWH(half, half, half, half),
      ],
    };
    final divider = size / 48;
    final dividerColor = Theme.of(context).colorScheme.surface;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: settingsFieldColor(context)),
            ),
            for (var i = 0; i < cells.length; i++)
              Positioned.fromRect(
                rect: cells[i],
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: math.max(cells[i].width, cells[i].height),
                    maxWidth: math.max(cells[i].width, cells[i].height),
                    minHeight: math.max(cells[i].width, cells[i].height),
                    maxHeight: math.max(cells[i].width, cells[i].height),
                    child: MemberAvatar(
                      sender: visible[i],
                      size: math.max(cells[i].width, cells[i].height),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
            if (visible.length >= 2)
              Positioned(
                left: half - divider / 2,
                top: 0,
                bottom: 0,
                width: divider,
                child: ColoredBox(color: dividerColor),
              ),
            if (visible.length >= 3)
              Positioned(
                left: visible.length == 3 ? half : 0,
                right: 0,
                top: half - divider / 2,
                height: divider,
                child: ColoredBox(color: dividerColor),
              ),
          ],
        ),
      ),
    );
  }
}
