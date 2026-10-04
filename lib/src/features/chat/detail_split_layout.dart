import 'package:flutter/material.dart';
import 'settings_appearance.dart';

class DetailSplitLayout extends StatelessWidget {
  const DetailSplitLayout({
    super.key,
    required this.animation,
    required this.opened,
    required this.child,
    this.detailBuilder,
  });
  final Animation<double> animation;
  final bool opened;
  final Widget child;
  final Widget Function(BuildContext, bool)? detailBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = width >= 600;
      final detailWidth = wide ? width / 2 : width;
      final dividerColor = Theme.of(context).dividerColor;
      final softDividerColor = dividerColor.withValues(
        alpha: dividerColor.a * 0.3,
      );
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final revealed = detailWidth * animation.value;
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  right: wide ? revealed : 0,
                  child: ExcludeFocus(
                    excluding: !wide && opened,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(
                          wide ? width - revealed : width,
                          constraints.maxHeight,
                        ),
                      ),
                      child: ClipRect(child: child),
                    ),
                  ),
                ),
                if (detailBuilder != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: width - revealed,
                    width: detailWidth,
                    child: Offstage(
                      offstage: (animation.value == 0),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: Size(detailWidth, constraints.maxHeight),
                        ),
                        child: Builder(
                          builder: (paneContext) => TickerMode(
                            enabled: !(animation.value == 0),
                            child: Builder(
                              builder: (detailContext) =>
                                  detailBuilder!(detailContext, wide),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (wide && !(animation.value == 0))
                  Positioned(
                    top: settingsHeaderHeight(context),
                    bottom: MediaQuery.paddingOf(context).bottom + 24,
                    left: width - revealed - 0.25,
                    width: 0.5,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: animation.value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.12, 0.88, 1],
                              colors: [
                                dividerColor.withValues(alpha: 0),
                                softDividerColor,
                                softDividerColor,
                                dividerColor.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
