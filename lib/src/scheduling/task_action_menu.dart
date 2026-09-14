import '../domain/error_message.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/conversation_icon.dart';
import 'scheduled_tasks.dart';

class TaskActionIcon extends StatelessWidget {
  const TaskActionIcon(this.action, {super.key});
  final String action;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    if (action == 'edit' || action == 'delete') {
      return ConversationMenuIcon(
        type: action == 'edit'
            ? ConversationMenuIconType.rename
            : ConversationMenuIconType.delete,
        color: action == 'delete' ? Theme.of(context).colorScheme.error : color,
      );
    }
    if (action == 'conversation')
      return ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: const ConversationIcon(),
      );
    return CustomPaint(
      size: const Size.square(24),
      painter: _ActionPainter(action, color),
    );
  }
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter(this.action, this.color);
  final String action;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (action == 'more') {
      for (final y in [5.0, 12.0, 19.0]) {
        canvas.drawCircle(Offset(12, y), 1.4, Paint()..color = color);
      }
      return;
    }
    if (action != 'resume') {
      canvas.drawCircle(const Offset(12, 12), 9, pen);
    }
    if (action == 'resume') {
      canvas.drawPath(
        Path()
          ..moveTo(7.5, 6.8)
          ..quadraticBezierTo(7.5, 5.3, 8.8, 6.1)
          ..lineTo(17.3, 10.9)
          ..quadraticBezierTo(19.1, 12, 17.3, 13.1)
          ..lineTo(8.8, 17.9)
          ..quadraticBezierTo(7.5, 18.7, 7.5, 17.2)
          ..close(),
        pen,
      );
    } else if (action == 'stop') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8.5, 8.5, 7, 7),
          const Radius.circular(1),
        ),
        pen,
      );
    } else {
      canvas.drawLine(const Offset(9, 8.5), const Offset(9, 15.5), pen);
      canvas.drawLine(const Offset(15, 8.5), const Offset(15, 15.5), pen);
    }
  }

  @override
  bool shouldRepaint(_ActionPainter old) =>
      old.action != action || old.color != color;
}

Future<String?> showTaskActionMenu(
  BuildContext context,
  Offset position,
  Map<String, Object?> task, {
  bool showEdit = true,
  bool showPauseResume = true,
}) {
  final state = task['state'];
  final running = state == 'starting' || state == 'running';
  final entries = <(String, String)>[
    if (showEdit && !running) ('edit', '编辑'),
    if (showPauseResume && state == 'scheduled') ('pause', '暂停'),
    if (showPauseResume && state == 'paused') ('resume', '恢复'),
    if (running) ('stop', '停止执行'),
    if (task['conversationId'] != null || task['sourceConversationId'] != null)
      ('conversation', '查看会话'),
    if (!running) ('delete', '删除'),
  ];
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭任务菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, _) {
      final media = MediaQuery.of(context);
      final width = math.min(
        212.0,
        media.size.width - media.padding.horizontal - 16,
      );
      final height = entries.length * 54.0 + 14;
      final left = position.dx.clamp(
        media.padding.left + 8,
        media.size.width - media.padding.right - width - 8,
      );
      final top = position.dy.clamp(
        media.padding.top + 8,
        math.max(
          media.padding.top + 8,
          media.size.height - media.padding.bottom - height - 8,
        ),
      );
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top.toDouble(),
            width: width,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: GlassSurface(
                radius: 24,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries)
                          InkWell(
                            borderRadius: BorderRadius.circular(17),
                            onTap: () => Navigator.pop(context, entry.$1),
                            child: SizedBox(
                              height: 54,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: [
                                    TaskActionIcon(entry.$1),
                                    const SizedBox(width: 13),
                                    Text(
                                      entry.$2,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: entry.$1 == 'delete'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<bool> manageTask(
  BuildContext context,
  ScheduledTasks tasks,
  String id,
  String action,
) async {
  if (action == 'delete') {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => const DeleteConfirmationDialog(
        title: '删除任务？',
        description: '删除后不再执行，已有会话会保留。',
      ),
    );
    if (yes != true || !context.mounted) return false;
  }
  try {
    await tasks.manage(id, action);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'delete' => '任务已删除',
            'pause' => '任务已暂停',
            'resume' => '任务已恢复',
            _ => '正在停止',
          }),
        ),
      );
    return true;
  } on Object catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is PlatformException
                ? e.message ?? '操作失败：${errorMessage(e)}'
                : '操作失败，请重试：${errorMessage(e)}',
          ),
        ),
      );
    return false;
  }
}

Future<void> openTaskConversation(
  BuildContext context,
  ChatController controller,
  Map<String, Object?> task,
) async {
  final id = (task['conversationId'] ?? task['sourceConversationId']) as String;
  try {
    await controller.selectConversation(id);
    if (context.mounted)
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            controller: controller,
            fromTask: true,
            originTaskId: task['id'] as String,
          ),
        ),
      );
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开对应会话，可能已被删除：${errorMessage(error)}')),
      );
  }
}
