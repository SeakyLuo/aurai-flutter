import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'html_game_session.dart';

class HtmlGameSurface extends StatelessWidget {
  const HtmlGameSurface({
    super.key,
    required this.session,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final HtmlGameSession session;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: Stack(
      children: [
        Positioned.fill(
          child: AndroidView(
            viewType: 'aurai/html_game',
            creationParams: {
              'document': session.document,
              'messageId': session.game.messageId,
              'identity': session.game.html + session.dark.toString(),
              'stateful': session.game.stateful,
              'fullscreen': session.fullscreen,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: session.bind,
          ),
        ),
        if (!session.ready)
          const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    ),
  );
}
