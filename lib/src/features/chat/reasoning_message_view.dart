import 'package:flutter/material.dart';

class ReasoningMessageView extends StatelessWidget {
  const ReasoningMessageView({
    super.key,
    required this.streaming,
    required this.child,
  });

  final bool streaming;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          streaming ? '正在思考…' : '思考过程',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
