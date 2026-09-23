import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'html_game_gestures.dart';
import 'html_game_session.dart';

class HtmlGameSurface extends StatelessWidget {
  const HtmlGameSurface({
    super.key,
    required this.session,
    this.preview,
    this.loadingBackground = Colors.transparent,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final HtmlGameSession session;
  final Uint8List? preview;
  final Color loadingBackground;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: Stack(
      children: [
        Positioned.fill(
          child: AndroidView(
            key: ObjectKey(session),
            viewType: 'aurai/html_game',
            gestureRecognizers: {
              Factory<HtmlGameGestureRecognizer>(
                () => HtmlGameGestureRecognizer(() => session.gestureRegions),
              ),
            },
            creationParams: {
              'messageId': session.game.messageId,
              'appId': session.game.appId,
              'storageKey': session.game.sessionScoped
                  ? 'message:${session.game.messageId}' : session.game.appId,
              'identity': session.identity,
              'stateful': session.game.stateful,
              'fullscreen': session.fullscreen,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: session.bind,
          ),
        ),
        if (!session.ready)
          // Cover the native surface through document and state restoration.
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: loadingBackground,
                child: preview != null
                    ? Image.memory(
                        preview!,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true,
                      )
                    : const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          ),
      ],
    ),
  );
}
