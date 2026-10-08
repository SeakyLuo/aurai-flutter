import 'package:flutter/material.dart';

import 'interactive_message_button.dart';

class InteractionTextPreview extends StatelessWidget {
  const InteractionTextPreview({
    super.key,
    required this.text,
    this.onShowDetails,
  });

  final String text;
  final VoidCallback? onShowDetails;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, height: 1.5);
    if (onShowDetails == null) return Text(text, style: style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 4,
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: style,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflow) ...[
              const SizedBox(height: 12),
              InteractiveMessageButton(
                button: const {'label': '查看详情', 'icon': 'none'},
                busy: false,
                locked: false,
                onPressed: onShowDetails!,
              ),
            ],
          ],
        );
      },
    );
  }
}
