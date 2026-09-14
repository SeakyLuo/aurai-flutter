import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'settings_icon.dart';
import 'conversation_menu_icon.dart';

class InteractiveMessageButton extends StatelessWidget {
  const InteractiveMessageButton({
    super.key,
    required this.button,
    required this.busy,
    required this.locked,
    required this.onPressed,
  });
  final Map<String, Object?> button;
  final bool busy;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final variant = button['style'] as String? ?? 'normal';
    final disabled = button['disabled'] == true;
    final primary = variant == 'primary';
    final tone = switch (variant) {
      'primary' => Colors.white,
      'success' => dark ? const Color(0xff82d9bb) : const Color(0xff168365),
      'danger' => dark ? const Color(0xffff969d) : const Color(0xffd7354d),
      'warning' => dark ? const Color(0xffffcc80) : const Color(0xff96600b),
      'info' => dark ? GlobalUI.primaryLight : const Color(0xff7355b5),
      _ => colors.onSurface,
    };
    final foreground = disabled
        ? colors.onSurfaceVariant.withValues(alpha: .6)
        : tone;
    final background = disabled
        ? colors.onSurface.withValues(alpha: .035)
        : primary
        ? Colors.transparent
        : variant == 'normal'
        ? colors.onSurface.withValues(alpha: .035)
        : variant == 'success'
        ? (dark ? const Color(0xff203d36) : const Color(0xffdef4ed))
        : variant == 'danger'
        ? (dark ? const Color(0xff472c34) : const Color(0xfffbe7ed))
        : variant == 'info'
        ? (dark ? const Color(0xff342c46) : const Color(0xffeee8fa))
        : tone.withValues(alpha: dark ? .13 : .07);
    final icon =
        button['icon'] as String? ??
        switch (button['action']) {
          'openUrl' => 'open',
          'acknowledge' => 'check',
          _ => 'info',
        };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: primary && !disabled
              ? const LinearGradient(
                  colors: [Color(0xffa18ae8), Color(0xff8165d3)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: primary && !disabled
              ? null
              : Border.all(
                  color: foreground.withValues(alpha: disabled ? .1 : .12),
                ),
        ),
        child: InkWell(
          onTap: locked || disabled ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  if (busy) ...[
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != 'none') ...[
                    SizedBox.square(
                      dimension: 18,
                      child: FittedBox(child: _icon(icon, foreground)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      button['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (button['showArrow'] == true && !disabled) ...[
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 16,
                      child: FittedBox(
                        child: SettingsIcon(
                          type: SettingsIconType.chevron,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(String name, Color color) => switch (name) {
    'delete' => ConversationMenuIcon(
      type: ConversationMenuIconType.delete,
      color: color,
    ),
    'check' => SettingsIcon(type: SettingsIconType.check, color: color),
    'info' => SettingsIcon(type: SettingsIconType.memory, color: color),
    'settings' => SettingsIcon(type: SettingsIconType.tools, color: color),
    _ => CustomPaint(
      size: const Size.square(24),
      painter: _ActionPainter(name, color),
    ),
  };
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter(this.name, this.color);
  final String name;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (name == 'play') {
      canvas.drawPath(
        Path()
          ..moveTo(7, 4)
          ..lineTo(19, 12)
          ..lineTo(7, 20)
          ..close(),
        pen,
      );
    } else if (name == 'reset') {
      canvas.drawArc(const Rect.fromLTWH(5, 5, 14, 14), -2.4, 5.4, false, pen);
      canvas.drawPath(
        Path()
          ..moveTo(5, 3)
          ..lineTo(5, 8)
          ..lineTo(10, 8),
        pen,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(13, 4)
          ..lineTo(20, 4)
          ..lineTo(20, 11)
          ..moveTo(20, 4)
          ..lineTo(11, 13)
          ..moveTo(8, 5)
          ..lineTo(4, 5)
          ..lineTo(4, 20)
          ..lineTo(19, 20)
          ..lineTo(19, 16),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_ActionPainter old) =>
      old.name != name || old.color != color;
}
