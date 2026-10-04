import 'package:flutter/material.dart';

class GroupMessageSelection extends StatefulWidget {
  const GroupMessageSelection({
    super.key,
    required this.child,
    required this.onChanged,
    required this.onOpenMenu,
    this.onQuote,
    this.onStar,
    this.onForward,
    this.onReadAloud,
  });
  final Widget child;
  final ValueChanged<String?> onChanged;
  final Future<bool> Function() onOpenMenu;
  final ValueChanged<String>? onQuote;
  final VoidCallback? onStar;
  final VoidCallback? onForward;
  final ValueChanged<String>? onReadAloud;

  @override
  State<GroupMessageSelection> createState() => GroupMessageSelectionState();
}

class GroupMessageSelectionState extends State<GroupMessageSelection> {
  final _selectionKey = GlobalKey<SelectionAreaState>();
  final _focus = FocusNode();
  bool _menuOpen = false;
  bool _selectionActive = false;
  String? _text;

  Future<void> openMenu() async {
    if (_menuOpen) return;
    _selectionActive = true;
    _menuOpen = true;
    await _showMenu();
  }

  Future<void> _showMenu() async {
    final selection = _selectionKey.currentState!.selectableRegion;
    _focus.requestFocus();
    selection.selectAll(SelectionChangedCause.toolbar);
    var acted = false;
    try {
      acted = await widget.onOpenMenu();
    } finally {
      if (selection.mounted) {
        selection.hideToolbar(acted);
        if (acted) selection.clearSelection();
      }
      _menuOpen = false;
      if (acted) _selectionActive = false;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    key: _selectionKey,
    focusNode: _focus,
    onSelectionChanged: (selection) {
      _text = selection?.plainText;
      widget.onChanged(_text);
      if (!_menuOpen && (_text == null || _text!.isEmpty)) {
        _selectionActive = false;
      }
    },
    contextMenuBuilder: (context, selection) {
      if (!_selectionActive && !_menuOpen) {
        _selectionActive = true;
        _menuOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !selection.mounted) return;
          await _showMenu();
        });
      }
      if (_menuOpen) return const SizedBox.shrink();
      void act(ValueChanged<String> callback) {
        final text = _text!;
        selection.hideToolbar();
        selection.clearSelection();
        callback(text);
      }

      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: selection.contextMenuAnchors,
        buttonItems: [
          ...selection.contextMenuButtonItems.where(
            (item) => item.type == ContextMenuButtonType.copy,
          ),
          if (widget.onQuote case final quote?)
            ContextMenuButtonItem(label: '引用', onPressed: () => act(quote)),
          if (widget.onStar case final star?)
            ContextMenuButtonItem(
              label: '收藏',
              onPressed: () => act((_) => star()),
            ),
          if (widget.onForward case final forward?)
            ContextMenuButtonItem(
              label: '转发',
              onPressed: () => act((_) => forward()),
            ),
          if (widget.onReadAloud case final read?)
            ContextMenuButtonItem(label: '朗读', onPressed: () => act(read)),
        ],
      );
    },
    child: widget.child,
  );
}
