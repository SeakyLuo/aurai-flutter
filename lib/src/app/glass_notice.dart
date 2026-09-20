import 'package:flutter/material.dart';
import '../features/chat/glass_surface.dart';

extension GlassNoticeMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showGlassSnackBar(
    SnackBar notice, {
    AnimationStyle? snackBarAnimationStyle,
  }) => showSnackBar(
    SnackBar(
      key: notice.key,
      content: _GlassNotice(notice: notice),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: notice.margin,
      width: notice.width,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.none,
      hitTestBehavior: notice.hitTestBehavior,
      duration: notice.duration,
      persist: notice.persist,
      animation: notice.animation,
      onVisible: notice.onVisible,
      dismissDirection: notice.dismissDirection,
      showCloseIcon: false,
    ),
    snackBarAnimationStyle: snackBarAnimationStyle,
  );
}

class _GlassNotice extends StatelessWidget {
  const _GlassNotice({required this.notice});
  final SnackBar notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyle = theme.textTheme.bodyMedium!.copyWith(
      color: colors.onSurface,
      height: 1.4,
    );
    final action = notice.action;
    final close =
        notice.showCloseIcon ?? theme.snackBarTheme.showCloseIcon ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
      child: GlassSurface(
        radius: 12,
        shadowOpacity: .6,
        gradientColors: theme.brightness == Brightness.dark
            ? const [Color(0xb3303032), Color(0xb3303032)]
            : const [Color(0xb3ffffff), Color(0xb3ffffff)],
        child: Theme(
          data: theme.copyWith(
            snackBarTheme: theme.snackBarTheme.copyWith(
              actionTextColor: theme.brightness == Brightness.dark
                  ? const Color(0xffc4b5fd)
                  : const Color(0xff7040b0),
              disabledActionTextColor: colors.onSurfaceVariant,
              actionBackgroundColor: Colors.transparent,
            ),
          ),
          child: DefaultTextStyle(
            style: textStyle,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                18,
                action != null || close ? 0 : 12,
                action != null || close ? 8 : 18,
                action != null || close ? 0 : 12,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final controls = <Widget>[
                    if (action != null) action,
                    if (close)
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            ScaffoldMessenger.of(context).hideCurrentSnackBar(
                              reason: SnackBarClosedReason.dismiss,
                            ),
                      ),
                  ];
                  final label = TextPainter(
                    text: TextSpan(
                      text: action?.label ?? '',
                      style: theme.textTheme.labelLarge,
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final actionWidth = action == null ? 0.0 : label.width + 32;
                  label.dispose();
                  final separateAction =
                      actionWidth + (close ? 48 : 0) >
                      constraints.maxWidth *
                          (notice.actionOverflowThreshold ?? .25);
                  if (controls.isEmpty) return notice.content;
                  if (separateAction)
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        notice.content,
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: controls,
                        ),
                      ],
                    );
                  return Row(
                    children: [
                      Expanded(child: notice.content),
                      const SizedBox(width: 8),
                      ...controls,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
