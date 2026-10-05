import 'app_bottom_sheet.dart';
import 'floating_search_layout.dart';
import 'package:flutter/material.dart';
import '../../domain/emoji_catalog.dart';
import '../../domain/quick_reply_option.dart';
import '../../storage/quick_reply_recents.dart';
import 'quick_reply_groups.dart';
import 'emoji_category_icon.dart';
import 'emoji_button.dart';

Future<QuickReplyOption?> showQuickReplyPicker(
  BuildContext context, {
  Set<String> selectedKeys = const {},
}) async {
  final (recent, catalog) = await (
    QuickReplyRecents.load(),
    EmojiCatalog.load(),
  ).wait;
  if (!context.mounted) return null;
  return showAppBottomSheet<QuickReplyOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _QuickReplyPicker(
      selectedKeys: selectedKeys,
      recent: recent,
      catalog: catalog,
    ),
  );
}

class _QuickReplyPicker extends StatefulWidget {
  const _QuickReplyPicker({
    required this.selectedKeys,
    required this.recent,
    required this.catalog,
  });
  final Set<String> selectedKeys;
  final List<String> recent;
  final EmojiCatalog catalog;
  @override
  State<_QuickReplyPicker> createState() => _QuickReplyPickerState();
}

class _QuickReplyPickerState extends State<_QuickReplyPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _category = -1;
  String _query = '';
  List<EmojiEntry> _results = [];
  final _preferredVariants = <String, EmojiEntry>{};

  @override
  void initState() {
    super.initState();
    for (final key in widget.recent.reversed) {
      final entry = widget.catalog.byKey[key];
      if (entry != null) _preferredVariants[entry.base] = entry;
    }
  }

  List<Color> _skinColors(String emoji) {
    const tones = [
      Color(0xffffcf45),
      Color(0xfff7dec3),
      Color(0xffe8bb98),
      Color(0xffc9916e),
      Color(0xffa66e4c),
      Color(0xff694632),
    ];
    final modifiers = emoji.runes
        .where((rune) => rune >= 0x1f3fb && rune <= 0x1f3ff)
        .toSet();
    return modifiers.isEmpty
        ? [tones[0]]
        : [for (final modifier in modifiers) tones[modifier - 0x1f3fb + 1]];
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {
      _query = value.trim();
      _results = _query.isEmpty ? [] : widget.catalog.search(_query);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _variants(EmojiEntry entry) async {
    final options = widget.catalog.variants[entry.base]!;
    final picked = await showAppBottomSheet<QuickReplyOption>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '选择肤色',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  gridDelegate: _grid,
                  itemCount: options.length,
                  itemBuilder: (_, index) => _tile(
                    options[index].option,
                    options[index].label,
                    onTap: () => Navigator.pop(context, options[index].option),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) Navigator.pop(context, picked);
  }

  static const _grid = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 6,
    childAspectRatio: 1,
    crossAxisSpacing: 4,
    mainAxisSpacing: 4,
  );

  Widget _tile(
    QuickReplyOption option,
    String label, {
    VoidCallback? onTap,
    Future<void> Function()? onLongPress,
  }) {
    final selected = widget.selectedKeys.contains(option.key);
    final skinColors = _skinColors(option.emoji);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      hint: onLongPress == null ? null : '长按选择肤色',
      child: EmojiButton(
        selected: selected,
        onTap: onTap ?? () => Navigator.pop(context, option),
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Center(
                child: Text(option.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            if (onLongPress != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: skinColors.length == 1 ? skinColors.single : null,
                    gradient: skinColors.length > 1
                        ? LinearGradient(colors: skinColors)
                        : null,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _entries(List<EmojiEntry> entries) => SliverGrid(
    gridDelegate: _grid,
    delegate: SliverChildBuilderDelegate((_, index) {
      final original = entries[index];
      final entry = _query.isEmpty
          ? (_preferredVariants[original.base] ?? original)
          : original;
      return _tile(
        entry.option,
        entry.label,
        onLongPress: widget.catalog.variants[entry.base]!.length > 1
            ? () => _variants(entry)
            : null,
      );
    }, childCount: entries.length),
  );

  Widget _heading(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final recent = recentQuickReplyKeys(widget.recent, 12);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .78 - keyboard).clamp(
          240.0,
          double.infinity,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_query.isEmpty)
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: emojiCategoryLabels.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 2),
                    itemBuilder: (context, index) {
                      final selected = _category == index - 1;
                      final label = index == 0
                          ? '全部'
                          : emojiCategoryLabels[index - 1];
                      final colors = Theme.of(context).colorScheme;
                      return Semantics(
                        selected: selected,
                        child: IconButton(
                          tooltip: label,
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(48),
                            backgroundColor: selected
                                ? colors.onSurface.withValues(alpha: .06)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: EmojiCategoryIcon(
                            category: index - 1,
                            color: selected
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() => _category = index - 1);
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          },
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: FloatingSearchLayout(
                  itemCount: widget.catalog.byKey.length,
                  controller: _search,
                  onChanged: _changed,
                  hintText: '搜索表情',
                  enabled: true,
                  bottom: 16,
                  child: CustomScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          FloatingSearchLayout.clearance,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            if (_query.isNotEmpty) ...[
                              _heading('搜索结果 · ${_results.length}'),
                              if (_results.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      '没有找到相关表情，试试其他关键词',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              _entries(_results),
                            ] else ...[
                              if (_category == -1) ...[
                                _heading(
                                  widget.recent.isEmpty ? '常用表情' : '最近使用',
                                ),
                                SliverGrid(
                                  gridDelegate: _grid,
                                  delegate: SliverChildBuilderDelegate((
                                    _,
                                    index,
                                  ) {
                                    final option =
                                        quickReplyOptionsByKey[recent[index]]!;
                                    final entry =
                                        widget.catalog.byKey[option.key];
                                    return _tile(
                                      option,
                                      entry?.label ?? option.emoji,
                                      onLongPress:
                                          entry != null &&
                                              widget
                                                      .catalog
                                                      .variants[entry.base]!
                                                      .length >
                                                  1
                                          ? () => _variants(entry)
                                          : null,
                                    );
                                  }, childCount: recent.length),
                                ),
                              ],
                              for (
                                var category = 0;
                                category < emojiCategoryLabels.length;
                                category++
                              )
                                if (_category == -1 ||
                                    _category == category) ...[
                                  _heading(emojiCategoryLabels[category]),
                                  _entries(widget.catalog.categories[category]),
                                ],
                            ],
                          ],
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
    );
  }
}
