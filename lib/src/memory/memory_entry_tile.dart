import 'package:flutter/material.dart';

class MemoryEntryTile extends StatefulWidget {
  const MemoryEntryTile({
    super.key,
    required this.text,
    required this.enabled,
    required this.onEdit,
    required this.onMenu,
  });
  final String text;
  final bool enabled;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMenu;

  @override
  State<MemoryEntryTile> createState() => _MemoryEntryTileState();
}

class _MemoryEntryTileState extends State<MemoryEntryTile> {
  bool _pressed = false;

  @override
  void didUpdateWidget(MemoryEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: '点按编辑，长按打开菜单',
    child: AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff242424)
            : const Color(0xfff7f7f7),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          onTap: widget.enabled ? widget.onEdit : null,
          onLongPress: !widget.enabled
              ? null
              : () {
                  setState(() => _pressed = false);
                  final box = context.findRenderObject()! as RenderBox;
                  widget.onMenu(
                    box.localToGlobal(
                      Offset(box.size.width / 2, box.size.height),
                    ),
                  );
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.text,
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
