import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../storage/quick_reply_recents.dart';
import 'attachment_action_icon.dart';
import 'copy_icon.dart';
import 'message_quote_view.dart';
import 'message_selection_menu.dart';
import 'quick_reply_picker.dart';
import 'settings_icon.dart';
import 'text_selection_icon.dart';

class GroupMessageSelection extends StatefulWidget {
  const GroupMessageSelection({
    super.key,
    required this.child,
    required this.onChanged,
    required this.loadOptions,
    required this.createdAt,
    this.onQuote,
    this.onStar,
    this.onForward,
    this.onReadAloud,
    this.onReaction,
    this.sentQuickReplyKeys = const {},
  });
  final Widget child;
  final ValueChanged<String?> onChanged;
  final Future<SelectionMenuOptions> Function() loadOptions;
  final DateTime createdAt;
  final ValueChanged<String>? onQuote;
  final VoidCallback? onStar;
  final VoidCallback? onForward;
  final ValueChanged<String>? onReadAloud;
  final ValueChanged<String>? onReaction;
  final Set<String> sentQuickReplyKeys;

  @override
  State<GroupMessageSelection> createState() => GroupMessageSelectionState();
}

class GroupMessageSelectionState extends State<GroupMessageSelection> {
  // Keep the menu in the selection overlay. Clearing selection removes that
  // overlay; never restore it independently of a live selection.

  final _selectionKey = GlobalKey<SelectionAreaState>();
  final _focus = FocusNode();
  bool _selectionActive = false;
  bool _selectingAll = false;
  int _menuSession = 0;
  String? _text;
  List<String> _recent = const [];
  bool _prepared = false;
  SelectionMenuOptions _options = (
    starred: false,
    visibility: null,
    actions: const [],
  );
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    _scrollPosition = position;
    position?.isScrollingNotifier.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollPosition!.isScrollingNotifier.value) {
      _selectionKey.currentState!.selectableRegion.hideToolbar(false);
    }
  }

  Future<bool> _prepareMenu() => runUiAction(context, () async {
    final (recent, options) = await (
      widget.onReaction == null
          ? Future.value(<String>[])
          : QuickReplyRecents.load(),
      widget.loadOptions(),
    ).wait;
    _recent = recent;
    _options = options;
    _prepared = true;
  });

  Future<void> openMenu() async {
    final session = ++_menuSession;
    _selectionActive = true;
    if (!await _prepareMenu() || !mounted || session != _menuSession) return;
    final selection = _selectionKey.currentState!.selectableRegion;
    _selectionActive = true;
    _focus.requestFocus();
    _selectAll(selection);
  }

  Future<void> _openReactions() async {
    // The toolbar's overlay context is disposed by hideToolbar. Open the picker
    // from this message's persistent context instead.
    final origin = context;
    final selection = _selectionKey.currentState!.selectableRegion;
    selection.hideToolbar();
    selection.clearSelection();
    await runUiAction(origin, () async {
      final option = await showQuickReplyPicker(
        origin,
        selectedKeys: widget.sentQuickReplyKeys,
      );
      if (mounted && option != null) widget.onReaction!(option.key);
    });
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
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
      if (!_selectingAll && (_text == null || _text!.isEmpty)) {
        _menuSession++;
        _selectionActive = false;
        _prepared = false;
        _selectionKey.currentState!.selectableRegion.hideToolbar();
      }
    },
    contextMenuBuilder: (context, selection) {
      if (!_selectionActive) {
        _selectionActive = true;
        final session = ++_menuSession;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !selection.mounted || session != _menuSession) return;
          if (!await _prepareMenu() ||
              !mounted ||
              !selection.mounted ||
              session != _menuSession)
            return;
          _selectAll(selection);
        });
      }
      if (!_prepared || (_text == null && !_selectingAll)) {
        return const SizedBox.shrink();
      }
      return _toolbar(context, selection);
    },
    child: widget.child,
  );

  void _selectAll(SelectableRegionState selection) {
    _selectingAll = true;
    selection.selectAll(SelectionChangedCause.toolbar);
    _selectingAll = false;
    _selectionActive = true;
  }

  Widget _toolbar(BuildContext context, SelectableRegionState selection) {
    void act(ValueChanged<String> callback) {
      final text = _text!;
      selection.hideToolbar();
      selection.clearSelection();
      callback(text);
    }

    final color = Theme.of(context).colorScheme.onSurface;
    final actions = <SelectionMenuAction>[
      for (final item in selection.contextMenuButtonItems)
        if (item.type == ContextMenuButtonType.copy)
          (
            label: '复制',
            icon: CopyIcon(color: color),
            onTap: () async {
              final origin = this.context;
              final text = _text!;
              final copied = await runUiAction(
                origin,
                () => Clipboard.setData(ClipboardData(text: text)),
              );
              if (!mounted || !copied) return;
              selection.hideToolbar();
              selection.clearSelection();
              ScaffoldMessenger.of(origin).showToast(
                const SnackBar(content: Text('已复制')),
                kind: ToastKind.success,
              );
            },
          ),
      if (widget.onQuote case final quote?)
        (label: '引用', icon: QuoteIcon(color: color), onTap: () => act(quote)),
      if (widget.onForward case final forward?)
        (
          label: '转发',
          icon: AttachmentActionIcon(
            type: AttachmentActionIconType.forward,
            color: color,
          ),
          onTap: () => act((_) => forward()),
        ),
      if (widget.onStar case final star?)
        (
          label: _options.starred ? '取消收藏' : '收藏',
          icon: SettingsIcon(
            type: _options.starred
                ? SettingsIconType.starFilled
                : SettingsIconType.star,
            color: color,
          ),
          onTap: () => act((_) => star()),
        ),
      (
        label: '全选',
        icon: TextSelectionIcon(color: color),
        onTap: () {
          _selectAll(selection);
        },
      ),
      if (widget.onReadAloud case final read?)
        (
          label: '朗读',
          icon: SettingsIcon(type: SettingsIconType.sound, color: color),
          onTap: () => act(read),
        ),
      for (final action in _options.actions)
        (
          label: action.label,
          icon: action.icon,
          onTap: () => act((_) => action.onTap()),
        ),
    ];
    final box = _selectionKey.currentContext!.findRenderObject()! as RenderBox;
    return MessageSelectionMenu(
      messageRect: box.localToGlobal(Offset.zero) & box.size,
      selectionHandles: [
        for (final endpoint in selection.selectionEndpoints)
          box.localToGlobal(endpoint.point),
      ],
      actions: actions,
      recent: _recent,
      createdAt: widget.createdAt,
      visibility: _options.visibility == null
          ? null
          : (
              label: _options.visibility!.label,
              onTap: () => act((_) => _options.visibility!.onTap()),
            ),
      sentQuickReplyKeys: widget.sentQuickReplyKeys,
      onReaction: widget.onReaction == null
          ? null
          : (key) => act((_) => widget.onReaction!(key)),
      onMoreReactions: _openReactions,
    );
  }
}
