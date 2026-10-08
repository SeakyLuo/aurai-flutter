import 'package:flutter/material.dart';
import '../../domain/message_quote.dart';
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
    final questions = quote.canView('user:local')
        ? quote.questions
        : const <String>[];
    final style = TextStyle(fontSize: 12, height: 1.35, color: color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: quote.canView('user:local') ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 9.5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 3),
                          if (questions.isNotEmpty)
                            for (final (index, question)
                                in questions.take(2).indexed)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 2,
                                ),
                                child: QuoteTextPreview(
                                  text: questions.length == 1
                                      ? '[问题] $question'
                                      : '[问题${index + 1}] $question${index == 1 && questions.length > 2 ? '…' : ''}',
                                  markdown: false,
                                  maxLines: 1,
                                  style: style,
                                ),
                              )
                          else
                            QuoteTextPreview(
                              text: quote.textFor('user:local'),
                              markdown: quote.markdown,
                              maxLines: 2,
                              style: style,
                            ),
                        ],
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
