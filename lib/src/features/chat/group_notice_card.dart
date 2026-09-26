import 'package:flutter/material.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import '../../app/global_ui.dart';

class GroupNoticeCard extends StatelessWidget {
  const GroupNoticeCard({
    super.key,
    required this.author,
    required this.time,
    required this.preview,
    required this.announcement,
    required this.onOpen,
    required this.onDismiss,
    required this.onOpenProfile,
  });
  final String author, time, preview;
  final bool announcement;
  final VoidCallback onOpen, onDismiss, onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      radius: 22,
      shadowOpacity: .65,
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                  child: Row(
                    children: [
                      Tooltip(
                        message: announcement ? '群公告' : '置顶消息',
                        child: ConversationMenuIcon(
                          type: announcement
                              ? ConversationMenuIconType.announcement
                              : ConversationMenuIconType.toTop,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Semantics(
                                    button: true,
                                    label: '查看$author的资料',
                                    child: InkWell(
                                      onTap: onOpenProfile,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Text(
                                        author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: GlobalUI.highlightTextColor(
                                            context,
                                          ),
                                          decoration: TextDecoration.none,
                                          fontSize: 12,
                                          height: 1.3,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    ' · $time',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.3,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: announcement ? '隐藏公告提示' : '关闭置顶提示',
              onPressed: onDismiss,
              icon: const QuestionIcon(type: QuestionIconType.close),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
