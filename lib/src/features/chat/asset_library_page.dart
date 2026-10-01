import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/library_asset.dart';
import '../../storage/asset_library.dart';
import '../../scheduling/task_filter_menu.dart';
import 'asset_library_dialogs.dart';
import 'asset_library_tile.dart';
import 'asset_library_grid.dart';
import 'asset_chat_picker.dart';
import 'asset_detail_page.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'attachment_action_icon.dart';
import 'conversation_icon.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'home_navigation.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';

part 'asset_library_page_actions.dart';

class AssetLibraryPage extends StatefulWidget {
  const AssetLibraryPage({
    super.key,
    required this.controller,
    this.trash = false,
    this.picking = false,
  });
  final ChatController controller;
  final bool trash, picking;
  @override
  State<AssetLibraryPage> createState() => _AssetLibraryPageState();
}

class _AssetLibraryPageState extends State<AssetLibraryPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchHidden = false;
  Timer? _searchReveal;
  final _scroll = ScrollController();
  final _items = <LibraryAsset>[];
  final _imageRatios = <String, double>{};
  final _selected = <String>{};
  AssetSource _source = AssetSource.generated;
  AssetType _type = AssetType.image;
  AssetSort _sort = AssetSort.newest;
  bool? _grid;
  bool _selecting = false,
      _loading = false,
      _more = true,
      _busy = false,
      _failed = false;
  Timer? _debounce;
  int _generation = 0;
  AssetLibrary get _library => widget.controller.assetLibrary;
  void _update(VoidCallback change) => setState(change);
  bool get _selectionMode => widget.picking || _selecting;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && !_loading && _more && !_failed)
        _perform(() => _load());
    });
    _perform(() => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchReveal?.cancel();
    _searchFocus.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  Future<void> _load({bool reset = false}) async {
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _selected.clear();
        _more = true;
      }
    });
    var succeeded = false;
    try {
      final page = await _library.page(
        offset: _items.length,
        query: _search.text.trim(),
        source: _source,
        type: _type,
        sort: _sort,
        trash: widget.trash,
      );
      final ratios = await Future.wait([
        for (final asset in page)
          if (asset.isImage && !_imageRatios.containsKey(asset.path))
            assetImageRatio(asset).then((ratio) => MapEntry(asset.path, ratio)),
      ]);
      succeeded = true;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _imageRatios.addEntries(ratios);
        _more = page.length == AssetLibrary.pageSize;
      });
    } finally {
      if (mounted && generation == _generation)
        setState(() {
          _loading = false;
          _failed = !succeeded;
        });
    }
  }

  void _toggle(LibraryAsset asset) => setState(() {
    _selecting = true;
    if (!_selected.add(asset.id)) _selected.remove(asset.id);
  });

  Future<void> _selectSource(BuildContext anchorContext) async {
    final box = anchorContext.findRenderObject()! as RenderBox;
    final value = await showTaskChoiceMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: _source.name,
      label: '筛选资料来源',
      centerOnAnchor: true,
      choices: [
        for (final source in AssetSource.values)
          (value: source.name, label: source.label),
      ],
    );
    if (value == null || !mounted) return;
    final source = AssetSource.values.byName(value);
    if (_source == source) return;
    setState(() => _source = source);
    await _load(reset: true);
  }

  Widget _sourceChoice() => Builder(
    builder: (anchorContext) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : () => _perform(() => _selectSource(anchorContext)),
      child: Semantics(
        button: true,
        label: '筛选资料来源',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 3, 5, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _source.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 3),
              const RotatedBox(
                quarterTurns: 1,
                child: SizedBox.square(
                  dimension: 12,
                  child: FittedBox(
                    child: SettingsIcon(type: SettingsIconType.chevron),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _typeTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        for (final type in const [
          AssetType.image,
          AssetType.document,
          AssetType.media,
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              button: true,
              selected: _type == type,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: _type == type
                    ? settingsFieldColor(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    if (_type == type) return;
                    setState(() => _type = type);
                    _perform(() => _load(reset: true));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _type == type
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _type == type
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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

  void _searchChanged(String value) {
    setState(() {});
    ++_generation;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _perform(() => _load(reset: true)),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _searchFocus.hasFocus || _selectionMode)
      return false;
    if (notification is ScrollStartNotification) {
      _searchReveal?.cancel();
      if (!_searchHidden) setState(() => _searchHidden = true);
    } else if (notification is ScrollEndNotification) {
      _searchReveal?.cancel();
      _searchReveal = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _searchHidden = false);
      });
    }
    return false;
  }

  Widget _searchBar() => GlassSurface(
    radius: 28,
    child: Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        onChanged: _searchChanged,
        onTapOutside: (_) => _searchFocus.unfocus(),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchFocus.unfocus(),
        decoration: InputDecoration(
          hintText: '搜索资料库',
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(14),
            child: SidebarActionIcon(type: SidebarActionIconType.search),
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  icon: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () {
                    _search.clear();
                    _searchChanged('');
                  },
                ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && (!_selecting || widget.picking),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy)
        setState(() {
          _selecting = false;
          _selected.clear();
        });
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: widget.trash ? '回收站' : '资料库',
        root: _selectionMode,
        onBack: _busy
            ? null
            : () {
                if (_selecting && !widget.picking) {
                  setState(() {
                    _selecting = false;
                    _selected.clear();
                  });
                } else {
                  Navigator.pop(context);
                }
              },
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectionMode
                  ? '已选择 ${_selected.length} 项'
                  : widget.trash
                  ? '回收站'
                  : '资料库',
            ),
            if (!_selectionMode || widget.picking) _sourceChoice(),
          ],
        ),
        actions: [
          if (_selectionMode)
            SettingsGlassAction(
              label: '取消选择',
              icon: Icons.close,
              iconWidget: const QuestionIcon(type: QuestionIconType.close),
              onPressed: _busy ? null : _closeSelection,
            )
          else
            Builder(
              builder: (buttonContext) => SettingsGlassAction(
                label: '更多',
                icon: Icons.more_vert,
                iconWidget: const SettingsIcon(type: SettingsIconType.more),
                onPressed: _busy
                    ? null
                    : () => _perform(() => _moreMenu(buttonContext)),
              ),
            ),
        ],
      ),
      body: SettingsPageBody(
        avoidHeader: true,
        child: SafeArea(
          top: false,
          child: AbsorbPointer(
            absorbing: _busy,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    _typeTabs(),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _onScroll,
                              child: _content(),
                            ),
                          ),
                          if (!_selectionMode)
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 16,
                              child: IgnorePointer(
                                ignoring: _searchHidden,
                                child: AnimatedSlide(
                                  offset: _searchHidden
                                      ? const Offset(0, 1.5)
                                      : Offset.zero,
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  child: AnimatedOpacity(
                                    opacity: _searchHidden ? 0 : 1,
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    child: _searchBar(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_selectionMode) _selectionActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _content() {
    if (_items.isEmpty && _loading)
      return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _failed)
      return Center(
        child: TextButton(
          onPressed: () => _perform(() => _load(reset: true)),
          child: const Text('重试'),
        ),
      );
    if (_items.isEmpty) {
      final label = _search.text.isNotEmpty
          ? '没有找到相关资料'
          : widget.trash
          ? '回收站为空'
          : '还没有${_type.label}';
      return Center(
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final grid = _grid ?? _type == AssetType.image;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: grid
              ? SliverGrid.builder(
                  gridDelegate: AssetLibraryGridDelegate([
                    for (final asset in _items)
                      asset.isImage ? _imageRatios[asset.path]! : .82,
                  ]),
                  itemCount: _items.length,
                  itemBuilder: (_, index) => _tile(_items[index], grid: true),
                )
              : SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _tile(_items[index]),
                ),
        ),
        if (_loading || _failed || _more)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: () => _perform(() => _load()),
                        child: Text(_failed ? '重试' : '加载更多'),
                      ),
              ),
            ),
          ),
        if (!_selectionMode)
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  Widget _tile(LibraryAsset asset, {bool grid = false}) => AssetLibraryTile(
    asset: asset,
    grid: grid,
    selectionMode: _selectionMode,
    selected: _selected.contains(asset.id),
    onSelect: () => _toggle(asset),
    onTap: () => _perform(() => _open(asset)),
    onMore: (context) => _perform(() => _assetMenu(context, asset)),
  );

  void _closeSelection() {
    if (widget.picking) {
      Navigator.pop(context);
    } else {
      setState(() {
        _selected.clear();
        _selecting = false;
        _searchHidden = false;
      });
    }
  }

  Widget _selectionActions() {
    final enabled = _selected.isNotEmpty && !_busy;
    final color = SettingsGlassAction.foregroundColor(
      context,
      enabled: enabled,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!widget.picking)
            SettingsGlassActionSurface(
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoundAction(
                      label: widget.trash ? '彻底删除' : '删除',
                      icon: Icons.delete_outline,
                      iconWidget: ConversationMenuIcon(
                        type: ConversationMenuIconType.delete,
                        color: color,
                      ),
                      onPressed: enabled
                          ? () => _perform(() => _delete(_selected.toList()))
                          : null,
                    ),
                    if (!widget.trash) ...[
                      const VerticalDivider(
                        width: 1,
                        indent: 12,
                        endIndent: 12,
                      ),
                      RoundAction(
                        label: '保存到设备',
                        icon: Icons.download,
                        iconWidget: AttachmentActionIcon(
                          type: AttachmentActionIconType.download,
                          color: color,
                        ),
                        onPressed: enabled
                            ? () => _perform(_saveSelected)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          SettingsGlassActionSurface(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                minimumSize: const Size(104, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: enabled
                  ? () => _perform(
                      () => widget.trash
                          ? _restore(_selected.toList())
                          : _useSelected(),
                    )
                  : null,
              icon: widget.trash
                  ? QuestionIcon(type: QuestionIconType.undo, color: color)
                  : ConversationIcon(color: color),
              label: Text(
                widget.trash
                    ? '恢复'
                    : widget.picking
                    ? '添加到聊天'
                    : '聊天',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
