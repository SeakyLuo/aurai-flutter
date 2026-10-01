import 'package:flutter/material.dart';
import '../features/chat/glass_surface.dart';
import 'notice_details_sheet.dart';

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
                  final content = notice.content;
                  final text = content is Text ? content : null;
                  final span = text == null
                      ? null
                      : text.textSpan ?? TextSpan(text: text.data);
                  final style = textStyle.merge(text?.style);
                  final direction =
                      text?.textDirection ?? Directionality.of(context);
                  final scaler =
                      text?.textScaler ?? MediaQuery.textScalerOf(context);
                  final measure = span == null
                      ? null
                      : (TextPainter(
                          text: TextSpan(style: style, children: [span]),
                          textDirection: direction,
                          textScaler: scaler,
                          maxLines: 4,
                          ellipsis: '…',
                          textAlign: text!.textAlign ?? TextAlign.start,
                          locale: text.locale,
                          strutStyle: text.strutStyle,
                          textWidthBasis:
                              text.textWidthBasis ?? TextWidthBasis.parent,
                          textHeightBehavior: text.textHeightBehavior,
                        )..layout(maxWidth: constraints.maxWidth));
                  final hasDetails = measure?.didExceedMaxLines ?? false;
                  measure?.dispose();
                  final preview = text == null
                      ? content
                      : Text.rich(
                          span!,
                          style: style,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: text.textAlign,
                          textDirection: direction,
                          textScaler: scaler,
                          locale: text.locale,
                          strutStyle: text.strutStyle,
                          textWidthBasis: text.textWidthBasis,
                          textHeightBehavior: text.textHeightBehavior,
                          semanticsLabel: text.semanticsLabel,
                        );
                  final controls = <Widget>[
                    if (hasDetails)
                      TextButton(
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);
                          showNoticeDetailsSheet(
                            context,
                            text: span!,
                            style: style,
                            action: action,
                          );
                          messenger.hideCurrentSnackBar(
                            reason: SnackBarClosedReason.dismiss,
                          );
                        },
                        child: const Text('详情'),
                      ),
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
                  if (controls.isEmpty) return preview;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      preview,
                      const SizedBox(height: 4),
                      Wrap(alignment: WrapAlignment.end, children: controls),
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
