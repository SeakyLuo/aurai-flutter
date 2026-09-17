import 'package:flutter/material.dart';

import '../../app/global_ui.dart';
import '../../domain/interactive_message.dart';
import 'interactive_message_view.dart';

class ForwardedInteractiveMessage extends StatelessWidget {
  const ForwardedInteractiveMessage({super.key, required this.card});

  final InteractiveMessage card;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: GlobalUI.messageBackground(Theme.of(context)),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: InteractiveMessageView(
          card: card,
          readOnly: true,
          onClick: (_, _, _, {value}) async => null,
          onOpenLink: (_) async {},
        ),
      ),
    ),
  );
}
