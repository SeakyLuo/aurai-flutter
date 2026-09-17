import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

Future<void> showSearchFilterMenu(
  BuildContext context, {
  required Rect anchor,
  required bool includeReasoning,
  required ValueChanged<bool> onChanged,
}) {
  final media = MediaQuery.of(context);
  final width = math.min(280.0, media.size.width - 32);
  var included = includeReasoning;
  return showGeneralDialog<void>(
    context: context,
    requestFocus: false,
    barrierDismissible: true,
    barrierLabel: '关闭搜索筛选',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => Stack(
      children: [
        Positioned(
          top: anchor.bottom + 8,
          right: 16,
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: GlassSurface(
              radius: 24,
              child: Material(
                type: MaterialType.transparency,
                child: StatefulBuilder(
                  builder: (context, setState) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('包含思考过程', style: TextStyle(fontSize: 15)),
                        ),
                        Switch.adaptive(
                          value: included,
                          onChanged: (value) {
                            setState(() => included = value);
                            onChanged(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
