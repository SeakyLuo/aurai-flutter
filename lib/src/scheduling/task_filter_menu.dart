import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/settings_icon.dart';

Future<String?> showTaskFilterMenu(
  BuildContext context, {
  required Rect anchor,
  required String selected,
}) => showTaskChoiceMenu(
  context,
  anchor: anchor,
  selected: selected,
  label: '筛选',
  choices: const [
    (value: 'all', label: '全部'),
    (value: 'active', label: '进行中'),
    (value: 'paused', label: '已暂停'),
    (value: 'history', label: '已结束'),
  ],
);

Future<String?> showTaskChoiceMenu(
  BuildContext context, {
  required Rect anchor,
  required String selected,
  required String label,
  required List<({String value, String label})> choices,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭$label菜单',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, animation, secondaryAnimation) {
    final media = MediaQuery.of(context);
    final width = math.min(
      212.0,
      media.size.width - media.padding.horizontal - 16,
    );
    final bottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        8;
    final height = choices.length * 52.0 + 14;
    final top =
        (anchor.bottom + 8 + height <= bottom
                ? anchor.bottom + 8
                : anchor.top - height - 8)
            .clamp(
              media.padding.top + 8,
              math.max(media.padding.top + 8, bottom - height),
            );
    final left = (anchor.right - width).clamp(
      media.padding.left + 8,
      media.size.width - media.padding.right - width - 8,
    );
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return Stack(
      children: [
        Positioned(
          top: top.toDouble(),
          left: left,
          width: width,
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              alignment: Alignment.topRight,
              scale: curve.drive(Tween(begin: .94, end: 1.0)),
              child: GlassSurface(
                radius: 24,
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bottom - top),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in choices)
                            Semantics(
                              button: true,
                              selected: selected == option.value,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(17),
                                onTap: () =>
                                    Navigator.pop(context, option.value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.3,
                                            fontWeight: FontWeight.w400,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: selected == option.value
                                            ? const SettingsIcon(
                                                type: SettingsIconType.check,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
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
      ],
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) => child,
);
