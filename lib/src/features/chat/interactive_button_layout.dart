import 'package:flutter/material.dart';

/// Keeps button behavior independent from the card's column count.
class InteractiveButtonLayout extends StatelessWidget {
  const InteractiveButtonLayout({
    super.key,
    required this.columns,
    required this.children,
  });

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < children.length; index += columns) ...[
        if (index > 0) const SizedBox(height: 8),
        if (columns == 1)
          children[index]
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[index]),
                const SizedBox(width: 8),
                if (index + 1 < children.length)
                  Expanded(child: children[index + 1])
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    ],
  );
}
