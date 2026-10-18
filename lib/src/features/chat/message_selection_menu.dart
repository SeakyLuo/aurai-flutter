import 'package:flutter/material.dart';

import '../../domain/quick_reply_option.dart';
import 'emoji_button.dart';
import 'glass_surface.dart';
import 'quick_reply_groups.dart';
import 'sidebar_action_icon.dart';
import 'message_time.dart';

typedef SelectionMenuAction = ({String label, Widget icon, VoidCallback onTap});
typedef SelectionMenuOptions = ({
  bool starred,
  List<SelectionMenuAction> actions,
});

/// Only the menu surface receives pointer events; the surrounding conversation
/// and selection handles remain interactive. Prefer the message's lower edge.
class MessageSelectionMenu extends StatelessWidget {
  const MessageSelectionMenu({
    super.key,
    required this.messageRect,
    required this.selectionHandles,
    required this.actions,
    required this.recent,
    required this.sentQuickReplyKeys,
    required this.createdAt,
    this.onReaction,
    this.onMoreReactions,
  });

  final Rect messageRect;
  final List<Offset> selectionHandles;
  final List<SelectionMenuAction> actions;
  final List<String> recent;
  final Set<String> sentQuickReplyKeys;
  final DateTime createdAt;
  final ValueChanged<String>? onReaction;
  final VoidCallback? onMoreReactions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = Rect.fromLTRB(
      12,
      media.padding.top + 12,
      media.size.width - 12,
      media.size.height - media.padding.bottom - media.viewInsets.bottom - 12,
    );
    return CustomSingleChildLayout(
      delegate: _MessageMenuPosition(messageRect, bounds, selectionHandles),
      child: GlassSurface(
        radius: 22,
        shadowOpacity: 2.5,
        gradientColors: Theme.of(context).brightness == Brightness.light
            ? const [Color(0xcceeeeee), Color(0xb3e4e4e4), Color(0xccececec)]
            : const [Color(0xcc383838), Color(0xb3282828), Color(0xcc303030)],
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onReaction != null) ...[
                  Builder(
                    builder: (context) {
                      final keys = recentQuickReplyKeys(recent, 5);
                      return Row(
                        children: [
                          for (final key in keys)
                            Expanded(
                              child: EmojiButton(
                                selected: sentQuickReplyKeys.contains(key),
                                onTap: () => onReaction!(key),
                                child: Text(
                                  quickReplyOptionsByKey[key]!.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Tooltip(
                              message: '更多表情',
                              child: Center(
                                child: IconButton(
                                  onPressed: onMoreReactions,
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size.square(44),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .07),
                                    shape: const CircleBorder(),
                                  ),
                                  icon: const SidebarActionIcon(
                                    type: SidebarActionIconType.add,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      messageTime(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 12, thickness: .5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 280 ? 4 : 5;
                    return Wrap(
                      children: [
                        for (final action in actions)
                          SizedBox(
                            width: constraints.maxWidth / columns,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: action.onTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 24,
                                      child: FittedBox(child: action.icon),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      action.label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageMenuPosition extends SingleChildLayoutDelegate {
  const _MessageMenuPosition(this.message, this.bounds, this.handles);
  final Rect message, bounds;
  final List<Offset> handles;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: bounds.width.clamp(0, 360),
        maxWidth: bounds.width.clamp(0, 360),
        maxHeight: bounds.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (message.center.dx - childSize.width / 2).clamp(
      bounds.left,
      bounds.right - childSize.width,
    );
    // Leave finger room around handles, including a selection in a long message
    // whose lower edge is off screen. No modal barrier is needed to place this.
    final candidates = [
      message.bottom + 28,
      message.top - childSize.height - 28,
      bounds.bottom - childSize.height,
      bounds.top,
      for (final handle in handles) ...[
        handle.dy + 36,
        handle.dy - childSize.height - 36,
      ],
    ];
    Offset? best;
    var leastOverlap = double.infinity;
    for (final candidate in candidates) {
      final position = Offset(
        x,
        candidate.clamp(bounds.top, bounds.bottom - childSize.height),
      );
      final rect = position & childSize;
      var overlap = 0.0;
      for (final handle in handles) {
        final intersection = rect.intersect(
          Rect.fromCircle(center: handle, radius: 28),
        );
        if (!intersection.isEmpty)
          overlap += intersection.width * intersection.height;
      }
      if (overlap == 0) return position;
      if (overlap < leastOverlap) {
        best = position;
        leastOverlap = overlap;
      }
    }
    return best!;
  }

  @override
  bool shouldRelayout(_MessageMenuPosition oldDelegate) =>
      oldDelegate.message != message ||
      oldDelegate.bounds != bounds ||
      oldDelegate.handles != handles;
}
