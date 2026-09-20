import 'package:flutter/material.dart';
import '../../domain/message_quote.dart';
import 'settings_appearance.dart';
import 'quote_text_preview.dart';

class MessageQuoteView extends StatelessWidget {
  const MessageQuoteView({
    super.key,
    required this.quote,
    this.onTap,
    this.onClose,
  });
  final MessageQuote quote;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    QuoteTextPreview(
                      text: quote.text,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: '取消引用',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 18, color: color),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuoteIcon extends StatelessWidget {
  const QuoteIcon({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(21),
    painter: _QuotePainter(
      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _QuotePainter extends CustomPainter {
  const _QuotePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final x in [4.0, 14.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 5.5, 6, 7),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + 6, 11)
          ..lineTo(x + 6, 13)
          ..quadraticBezierTo(x + 6, 17, x + 1.5, 18.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QuotePainter oldDelegate) => color != oldDelegate.color;
}
