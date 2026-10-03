import 'floating_search_layout.dart';
import 'package:flutter/material.dart';

import '../../domain/avatar_style.dart';
import '../../domain/emoji_catalog.dart';
import 'avatar_symbol.dart';
import 'emoji_category_icon.dart';
import 'profile_avatar.dart';
import 'question_icon.dart';
import 'search_type_segment.dart';
import 'glass_surface.dart';

Future<String?> showAvatarSymbolPicker(
  BuildContext context, {
  required String selected,
  required String color,
  required String name,
  Map<String, String> symbols = avatarSymbols,
  Widget Function(String value)? previewBuilder,
}) async {
  final catalog = await EmojiCatalog.load();
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: .24),
    builder: (_) => _AvatarSymbolPicker(
      selected: selected,
      color: color,
      name: name,
      catalog: catalog,
      symbols: symbols,
      previewBuilder: previewBuilder,
    ),
  );
}

class _AvatarSymbolPicker extends StatefulWidget {
  const _AvatarSymbolPicker({
    required this.selected,
    required this.color,
    required this.name,
    required this.catalog,
    required this.symbols,
    this.previewBuilder,
  });

  final String selected;
  final String color;
  final String name;
  final EmojiCatalog catalog;
  final Map<String, String> symbols;
  final Widget Function(String value)? previewBuilder;

  @override
  State<_AvatarSymbolPicker> createState() => _AvatarSymbolPickerState();
}

class _AvatarSymbolPickerState extends State<_AvatarSymbolPicker> {
  final _search = TextEditingController();
  late int _mode = _hasPortraits ? 2 : 0;
  bool get _emoji => _mode == 1;
  bool get _hasPortraits =>
      widget.symbols.keys.any((key) => key.startsWith('portrait:'));
  int _category = -1;
  String _query = '';
  List<EmojiEntry> _results = const [];

  List<EmojiEntry> get _emojis => _query.isNotEmpty
      ? _results
      : _category == -1
      ? [for (final category in widget.catalog.categories) ...category]
      : widget.catalog.categories[_category];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _results = query.isEmpty ? const [] : widget.catalog.search(query);
    });
  }

  void _changeMode(int mode) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  RoundAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: SearchTypeSegment.indexed(
                        index: _hasPortraits ? 2 - _mode : _mode,
                        labels: _hasPortraits
                            ? ['插画', 'Emoji', '图标']
                            : ['图标', 'Emoji'],
                        onChanged: (index) =>
                            _changeMode(_hasPortraits ? 2 - index : index),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            if (_emoji && _query.isEmpty) _categories(),
            if (_showCurrentEmoji) _currentEmojiRow(),
            if (_showCurrentEmoji) _allEmojiHeading(),
            Expanded(
              child: FloatingSearchLayout(
                itemCount: _emojis.length,
                controller: _search,
                onChanged: _searchChanged,
                hintText: '搜索 Emoji',
                enabled: _emoji,
                bottom: 16,
                child: _emoji ? _emojiGrid() : _iconGrid(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  bool get _showCurrentEmoji =>
      _emoji &&
      _query.isEmpty &&
      _category == -1 &&
      widget.selected.startsWith('emoji:');

  Widget _currentEmojiRow() => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SizedBox.square(dimension: 60, child: _choice(widget.selected, '当前')),
        ],
      ),
    ),
  );

  Widget _allEmojiHeading() => const SizedBox(
    width: double.infinity,
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(
        '全部',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _categories() => SizedBox(
    height: 58,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      scrollDirection: Axis.horizontal,
      itemCount: emojiCategoryLabels.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 2),
      itemBuilder: (context, index) {
        final category = index - 1;
        final selected = _category == category;
        final colors = Theme.of(context).colorScheme;
        return Semantics(
          selected: selected,
          button: true,
          child: IconButton(
            tooltip: category == -1 ? '全部' : emojiCategoryLabels[category],
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              backgroundColor: selected
                  ? colors.onSurface.withValues(alpha: .06)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _category = category),
            icon: EmojiCategoryIcon(
              category: category,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        );
      },
    ),
  );

  Widget _iconGrid() {
    final entries = widget.symbols.entries
        .where((entry) => entry.key.startsWith('portrait:') == (_mode == 2))
        .toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        FloatingSearchLayout.clearance,
      ),
      gridDelegate: _mode == 2 ? _portraitGridDelegate : _iconGridDelegate,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _choice(entry.key, entry.value);
      },
    );
  }

  Widget _emojiGrid() {
    final entries = [
      for (final entry in _emojis)
        if (!_showCurrentEmoji || 'emoji:${entry.emoji}' != widget.selected)
          entry,
    ];
    if (_query.isNotEmpty && entries.isEmpty) {
      return Center(
        child: Text(
          '没有找到相关 Emoji',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return GridView.builder(
      key: ValueKey((_category, _query)),
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        FloatingSearchLayout.clearance,
      ),
      gridDelegate: _emojiGridDelegate,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final value = 'emoji:${entry.emoji}';
        return _choice(value, entry.label);
      },
    );
  }

  static const _iconGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 5,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );

  static const _portraitGridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      );

  static const _emojiGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 6,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  );

  Widget _choice(String value, String label) {
    final selected = widget.selected == value;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.pop(context, value),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child:
                widget.previewBuilder?.call(value) ??
                ProfileAvatar(
                  style: AvatarStyle(icon: value, color: widget.color),
                  name: widget.name,
                  size: _mode == 2 ? 60 : 44,
                ),
          ),
        ),
      ),
    );
  }
}
