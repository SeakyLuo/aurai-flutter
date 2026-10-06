import 'dart:async';
import 'package:flutter/material.dart';
import '../features/chat/glass_surface.dart';
import 'notice_details_sheet.dart';
import 'global_ui.dart';

enum ToastKind { info, success, error, warning }

class ToastHandle {
  ToastHandle(this.close);
  final VoidCallback close;
}

abstract final class AppToasts {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final startupNavigatorKey = GlobalKey<NavigatorState>();
  static final _queues = Expando<_ToastQueue>();

  static ToastHandle show(SnackBar notice, {ToastKind kind = ToastKind.info}) {
    final overlay =
        (navigatorKey.currentState ?? startupNavigatorKey.currentState)!
            .overlay!;
    final queue = _queues[overlay] ??= _ToastQueue(overlay);
    return queue.show(notice, kind);
  }

  static void dismiss() {
    final overlay =
        (navigatorKey.currentState ?? startupNavigatorKey.currentState)
            ?.overlay;
    if (overlay != null) _queues[overlay]?.dismiss();
  }
}

// Keep notification content and existing action callbacks at one presentation boundary.
extension GlassNoticeMessenger on ScaffoldMessengerState {
  ToastHandle showToast(SnackBar notice, {ToastKind kind = ToastKind.info}) =>
      AppToasts.show(notice, kind: kind);
}

class _ToastQueue {
  _ToastQueue(this.overlay);
  final OverlayState overlay;
  OverlayEntry? _entry;
  ValueNotifier<bool>? _closing;
  ({SnackBar notice, ToastKind kind, Object token})? _pending;
  Object? _activeToken;

  ToastHandle show(SnackBar notice, ToastKind kind) {
    final token = Object();
    _pending = (notice: notice, kind: kind, token: token);
    if (_entry != null) {
      _closing!.value = true;
    } else {
      _next();
    }
    return ToastHandle(() {
      if (_pending?.token == token) _pending = null;
      if (_activeToken == token) _closing!.value = true;
    });
  }

  void dismiss() {
    _pending = null;
    _closing?.value = true;
  }

  void _next() {
    final next = _pending;
    if (next == null || !overlay.mounted) return;
    _pending = null;
    _activeToken = next.token;
    final closing = ValueNotifier(false);
    _closing = closing;
    _entry = OverlayEntry(
      builder: (_) => _TopToast(
        notice: next.notice,
        kind: next.kind,
        closing: closing,
        onDisposed: () {
          if (_activeToken == next.token) {
            _activeToken = null;
            _closing = null;
            _entry = null;
            _pending = null;
          }
        },
        onClosed: () {
          _entry!.remove();
          _entry!.dispose();
          _entry = null;
          _closing = null;
          _activeToken = null;
          _next();
        },
      ),
    );
    overlay.insert(_entry!);
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.notice,
    required this.kind,
    required this.closing,
    required this.onClosed,
    required this.onDisposed,
  });
  final SnackBar notice;
  final ToastKind kind;
  final ValueNotifier<bool> closing;
  final VoidCallback onClosed;
  final VoidCallback onDisposed;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    widget.closing.addListener(_dismiss);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.closing.value) {
        _dismiss();
        return;
      }
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        await _animation.forward();
      }
      if (!mounted || _closing) return;
      widget.notice.onVisible?.call();
      if (!widget.notice.persist &&
          !(MediaQuery.accessibleNavigationOf(context) &&
              widget.notice.action != null)) {
        _timer = Timer(widget.notice.duration, _dismiss);
      }
    });
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _animation.reverse();
    }
    if (mounted) widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onDisposed();
    widget.closing.removeListener(_dismiss);
    widget.closing.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (widget.kind) {
      ToastKind.success =>
        dark ? const Color(0xff6ed4aa) : const Color(0xff24845d),
      ToastKind.error ||
      ToastKind.warning => dark ? GlobalUI.darkWarningRed : GlobalUI.warningRed,
      ToastKind.info =>
        dark ? const Color(0xff64b5f6) : const Color(0xff2196f3),
    };
    final animation = _animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: MediaQuery.paddingOf(context).left + 20,
      right: MediaQuery.paddingOf(context).right + 20,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0, -.35), end: Offset.zero),
              ),
              child: Semantics(
                liveRegion: true,
                child: GestureDetector(
                  onTap: widget.notice.dismissDirection == DismissDirection.none
                      ? null
                      : _dismiss,
                  onVerticalDragEnd:
                      widget.notice.dismissDirection == DismissDirection.none
                      ? null
                      : (details) {
                          if (details.primaryVelocity! < 0) _dismiss();
                        },
                  child: GlassSurface(
                    radius: 20,
                    gradientColors: dark
                        ? const [
                            Color(0xe038383c),
                            Color(0xcc29292e),
                            Color(0xe02e2e33),
                          ]
                        : const [
                            Color(0xefffffff),
                            Color(0xd6ffffff),
                            Color(0xe6f5f5f8),
                          ],
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ToastIcon(kind: widget.kind, color: color),
                            const SizedBox(width: 12),
                            Expanded(child: _content(context)),
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

  Widget _content(BuildContext context) {
    final content = widget.notice.content;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.45,
    );
    final action = widget.notice.action;
    return DefaultTextStyle(
      style: style,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = content is Text ? content : null;
          final span = text?.textSpan ?? TextSpan(text: text?.data);
          final painter = text == null
              ? null
              : (TextPainter(
                  text: TextSpan(style: style, children: [span]),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 4,
                  ellipsis: '…',
                )..layout(maxWidth: constraints.maxWidth));
          final hasDetails = painter?.didExceedMaxLines ?? false;
          final inlineAction =
              action != null &&
              painter != null &&
              !hasDetails &&
              painter.maxIntrinsicWidth +
                      12 +
                      _ToastActionButton.widthFor(context, action.label) <=
                  constraints.maxWidth;
          painter?.dispose();
          if (inlineAction) {
            return Row(
              children: [
                Expanded(child: Text.rich(span, style: style)),
                const SizedBox(width: 12),
                _ToastActionButton(
                  label: action.label,
                  onPressed: () {
                    _dismiss();
                    action.onPressed();
                  },
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: text == null
                      ? content
                      : Text.rich(
                          span,
                          style: style,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (hasDetails || action != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasDetails)
                          _ToastActionButton(
                            label: '查看详情',
                            onPressed: () {
                              showNoticeDetailsSheet(
                                context,
                                text: span,
                                style: style,
                              );
                              _dismiss();
                            },
                          ),
                        if (action != null)
                          _ToastActionButton(
                            label: action.label,
                            onPressed: () {
                              _dismiss();
                              action.onPressed();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const _textStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static double widthFor(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge!.merge(_textStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + 28).clamp(64.0, double.infinity);
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: GlobalUI.messageBackground(theme),
        minimumSize: const Size(64, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        shape: const StadiumBorder(),
        textStyle: theme.textTheme.labelLarge!.merge(_textStyle),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

class _ToastIcon extends StatelessWidget {
  const _ToastIcon({required this.kind, required this.color});
  final ToastKind kind;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _StatusPainter(kind, color),
  );
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.kind, this.color);
  final ToastKind kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.65
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 12), 9, paint);
    switch (kind) {
      case ToastKind.success:
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 12)
            ..lineTo(10.5, 15)
            ..lineTo(16.5, 9),
          paint,
        );
      case ToastKind.error:
        canvas.drawLine(const Offset(9, 9), const Offset(15, 15), paint);
        canvas.drawLine(const Offset(15, 9), const Offset(9, 15), paint);
      case ToastKind.warning:
        canvas.drawLine(const Offset(12, 7.5), const Offset(12, 12.5), paint);
        canvas.drawCircle(
          const Offset(12, 16),
          .8,
          paint..style = PaintingStyle.fill,
        );
      case ToastKind.info:
        canvas.drawCircle(const Offset(12, 12), 9, Paint()..color = color);
        paint.color = Colors.white;
        canvas.drawLine(const Offset(12, 10.5), const Offset(12, 16.5), paint);
        canvas.drawCircle(
          const Offset(12, 7.5),
          .9,
          paint..style = PaintingStyle.fill,
        );
    }
  }

  @override
  bool shouldRepaint(_StatusPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
