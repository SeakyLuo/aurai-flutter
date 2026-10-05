import 'package:flutter/material.dart';

import 'app_sheet_surface.dart';
import 'chat_header_background.dart';

/// Shared sheet layout: scrolling content passes behind the fading header.
/// Put [headerExtent] in the scroll view's top padding, not outside it.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.header,
    required this.child,
    this.shrinkWrap = false,
    this.headerExtent = 68,
  });

  final Widget header, child;
  final bool shrinkWrap;
  final double headerExtent;

  @override
  Widget build(BuildContext context) => AppSheetSurface(
    child: Stack(
      children: [
        if (shrinkWrap) child else Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerExtent + 12,
          child: const IgnorePointer(child: ChatHeaderBackground()),
        ),
        Positioned(top: 0, left: 0, right: 0, child: header),
      ],
    ),
  );
}
