import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

typedef HeaderMenuItem = ({String value, String label, Widget icon});

Future<String?> showHeaderActionMenu(
  BuildContext context, {
  required List<HeaderMenuItem> items,
  Set<String> destructiveValues = const {},
}) {
  final button = context.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
  final media = MediaQuery.of(context);
  final width = math.min(
    212.0,
    media.size.width - media.padding.horizontal - 16,
  );
  final left = (origin.dx + button.size.width - width).clamp(
    media.padding.left + 8,
    media.size.width - media.padding.right - width - 8,
  );
  return showGeneralDialog<String>(
    context: context,
    requestFocus: false,
    barrierDismissible: true,
    barrierLabel: '关闭菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, _) {
      final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return Stack(
        children: [
          CustomSingleChildLayout(
            delegate: _MenuPosition(
              left: left,
              anchor: origin & button.size,
              width: width,
              topInset: media.padding.top + 8,
              bottomInset: media.padding.bottom + 8,
            ),
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: curve.drive(Tween(begin: .94, end: 1.0)),
                child: GlassSurface(
                  radius: 24,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in items)
                            InkWell(
                              borderRadius: BorderRadius.circular(17),
                              onTap: () => Navigator.pop(context, item.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                                child: Row(
                                  children: [
                                    item.icon,
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color:
                                              destructiveValues.contains(
                                                item.value,
                                              )
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.error
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
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
        ],
      );
    },
    transitionBuilder: (_, _, _, child) => child,
  );
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition({
    required this.left,
    required this.anchor,
    required this.width,
    required this.topInset,
    required this.bottomInset,
  });
  final double left, width, topInset, bottomInset;
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, constraints.maxHeight - topInset - bottomInset),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = anchor.bottom + 8;
    final top = below + childSize.height <= size.height - bottomInset
        ? below
        : anchor.top - childSize.height - 8;
    return Offset(
      left,
      top.clamp(
        topInset,
        math.max(topInset, size.height - bottomInset - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition oldDelegate) =>
      left != oldDelegate.left ||
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      topInset != oldDelegate.topInset ||
      bottomInset != oldDelegate.bottomInset;
}
