import 'package:flutter/material.dart';

import 'settings_icon.dart';

class ModelRemovalRow extends StatefulWidget {
  const ModelRemovalRow({
    super.key,
    required this.enabled,
    required this.onRemove,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<ModelRemovalRow> createState() => _ModelRemovalRowState();
}

class _ModelRemovalRowState extends State<ModelRemovalRow>
    with SingleTickerProviderStateMixin {
  static const _extent = 64.0;
  late final _offset = AnimationController(
    vsync: this,
    upperBound: _extent,
    duration: const Duration(milliseconds: 180),
  );

  void _settle(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = target;
    } else {
      _offset.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: GestureDetector(
      onHorizontalDragStart: widget.enabled ? (_) => _offset.stop() : null,
      onHorizontalDragUpdate: widget.enabled
          ? (details) => _offset.value = (_offset.value - details.delta.dx)
                .clamp(0, _extent)
          : null,
      onHorizontalDragEnd: widget.enabled
          ? (details) => _settle(
              details.velocity.pixelsPerSecond.dx < -300
                  ? _extent
                  : details.velocity.pixelsPerSecond.dx > 300
                  ? 0
                  : _offset.value >= _extent / 2
                  ? _extent
                  : 0,
            )
          : null,
      onHorizontalDragCancel: () => _settle(0),
      child: AnimatedBuilder(
        animation: _offset,
        child: widget.child,
        builder: (context, child) => Stack(
          alignment: Alignment.centerRight,
          children: [
            if (_offset.value > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _extent,
                    child: Center(
                      child: IconButton(
                        tooltip: '删除模型',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          minimumSize: const Size.square(48),
                        ),
                        onPressed: widget.enabled ? widget.onRemove : null,
                        icon: SettingsIcon(
                          type: SettingsIconType.remove,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(-_offset.value, 0),
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}
