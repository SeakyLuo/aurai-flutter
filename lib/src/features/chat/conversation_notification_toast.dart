import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'glass_surface.dart';

class ConversationNotificationToast extends StatefulWidget {
  const ConversationNotificationToast({
    super.key,
    required this.title,
    required this.avatar,
    required this.reply,
    required this.onOpen,
    required this.onDismiss,
  });

  final String title;
  final Future<Uint8List> avatar;
  final String reply;
  final bool Function() onOpen;
  final VoidCallback onDismiss;

  @override
  State<ConversationNotificationToast> createState() =>
      _ConversationNotificationToastState();
}

class _ConversationNotificationToastState
    extends State<ConversationNotificationToast> {
  late final Timer _timer;
  bool _closing = false;

  void _dismiss() {
    if (_closing) return;
    _timer.cancel();
    setState(() => _closing = true);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), _dismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: MediaQuery.paddingOf(context).left + 16,
      right: MediaQuery.paddingOf(context).right + 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _closing ? 0 : 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Duration(milliseconds: _closing ? 240 : 200),
            curve: _closing ? Curves.easeInCubic : Curves.easeOutCubic,
            onEnd: () {
              if (_closing) widget.onDismiss();
            },
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: child,
              ),
            ),
            child: Dismissible(
              key: const ValueKey('completion-notification'),
              direction: DismissDirection.up,
              resizeDuration: null,
              onDismissed: (_) => widget.onDismiss(),
              child: Semantics(
                button: true,
                liveRegion: true,
                label: '回复已完成，点按打开会话',
                onDismiss: _dismiss,
                child: GlassSurface(
                  radius: 24,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () {
                        if (!_closing && widget.onOpen()) _dismiss();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 16, 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                SizedBox.square(
                                  dimension: 38,
                                  child: FutureBuilder<Uint8List>(
                                    future: widget.avatar,
                                    builder: (context, snapshot) =>
                                        snapshot.hasData
                                        ? Image.memory(
                                            snapshot.data!,
                                            width: 38,
                                            height: 38,
                                            excludeFromSemantics: true,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.3,
                                                fontWeight: FontWeight.w600,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '现在',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.reply,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 40,
                              height: 3,
                              decoration: BoxDecoration(
                                color: colors.onSurface.withValues(alpha: .22),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
