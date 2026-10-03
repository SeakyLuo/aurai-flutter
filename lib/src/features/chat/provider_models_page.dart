import 'floating_search_layout.dart';
import 'model_selection_bar.dart';
import '../../widgets/empty_data_view.dart';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'model_detail_page.dart';
import 'model_list_skeleton.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'question_icon.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';

class ProviderModelsPage extends StatefulWidget {
  const ProviderModelsPage({
    super.key,
    required this.controller,
    required this.config,
    this.selectable = false,
    this.onConfigureTypes,
    this.onDefaultSettings,
  });
  final ChatController controller;
  final ModelConfig config;
  final bool selectable;
  final Future<bool> Function()? onConfigureTypes;
  final Future<void> Function()? onDefaultSettings;
  @override
  State<ProviderModelsPage> createState() => _ProviderModelsPageState();
}

class _ProviderModelsPageState extends State<ProviderModelsPage> {
  List<String> _models = [];
  final _search = TextEditingController();
  final _selected = <String>{};
  bool _loaded = false;
  bool _requestFailed = false;
  bool _changed = false;
  bool _selectedOnly = false;
  final _selectedFilterModels = <String>{};
  late bool _useAll = widget.config.autoSyncModels;
  ModelCatalog? _catalog;
  bool _fetching = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  void _notice(String text, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(text)), kind: kind);

  @override
  void dispose() {
    _catalog?.close();
    _search.dispose();
    super.dispose();
  }

  bool _canConnect() {
    if (widget.config.apiKey.isEmpty && !widget.config.isSpeechConfigured) {
      _notice('请返回供应商页，点击编辑填写 API 密钥');
      return false;
    }
    final uri = Uri.tryParse(widget.config.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      _notice('请返回供应商页填写有效的 HTTPS API 地址');
      return false;
    }
    return true;
  }

  Future<void> _fetch() async {
    if (_catalog != null) return;
    if (!_loaded && !widget.selectable && !widget.config.autoSyncModels) {
      setState(() {
        _models = widget.config.savedModels;
        _selected.addAll(_models);
        _loaded = true;
      });
    }
    if (!_canConnect()) {
      setState(() => _fetching = false);
      return;
    }
    setState(() => _fetching = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.loadFor(widget.config);
      if (mounted)
        setState(() {
          _models = models;
          if (!_loaded) {
            _selected.clear();
            _selected.addAll(widget.config.savedModels);
            if (_useAll) _selected.addAll(models);
          }
          _loaded = true;
          _requestFailed = false;
        });
    } on ModelProviderException catch (error) {
      _requestFailed = true;
      if (mounted) _notice(error.message, kind: ToastKind.error);
    } catch (_) {
      _requestFailed = true;
      if (mounted) _notice('读取模型失败，请返回检查供应商配置后重新打开', kind: ToastKind.error);
    } finally {
      catalog.close();
      _catalog = null;
      if (mounted) setState(() => _fetching = false);
    }
  }

  bool get _canSave => _loaded && !_requestFailed && !_fetching && _changed;

  void _toggle(String model) => setState(() {
    if (!_selected.remove(model)) _selected.add(model);
    _changed = true;
  });

  void _selectBatch(List<String> shown) => setState(() {
    if (shown.every(_selected.contains)) {
      _selected.removeAll(shown);
    } else {
      _selected.addAll(shown);
    }
    _changed = true;
  });

  void _saveSelection() {
    if (!_useAll && _selected.isEmpty) {
      _notice('请至少选择一个模型', kind: ToastKind.warning);
      return;
    }
    Navigator.pop(context, (useAll: _useAll, models: _selected.toList()));
  }

  Future<void> _showFilter(BuildContext anchor, List<String> shown) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        if (widget.selectable &&
            !_useAll &&
            _search.text.trim().isNotEmpty &&
            shown.isNotEmpty)
          (
            value: 'searchResults',
            label: shown.every(_selected.contains) ? '取消选择搜索结果' : '全选搜索结果',
            icon: const SettingsIcon(type: SettingsIconType.check),
          ),
        if (widget.selectable && !_useAll)
          (
            value: 'selected',
            label: _selectedOnly ? '显示全部模型' : '只看已选模型',
            icon: const SettingsIcon(type: SettingsIconType.check),
          ),
        if (widget.selectable)
          (
            value: 'useAll',
            label: _useAll ? '关闭使用全部' : '使用全部模型',
            icon: const SettingsIcon(type: SettingsIconType.grid),
          ),
        if (widget.onConfigureTypes != null)
          (
            value: 'types',
            label: '模型类型识别',
            icon: const SettingsIcon(type: SettingsIconType.field),
          ),
        if (widget.onDefaultSettings != null)
          (
            value: 'defaults',
            label: '默认模型设置',
            icon: const SettingsIcon(type: SettingsIconType.modelSettings),
          ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'searchResults') {
      _selectBatch(shown);
      return;
    }
    if (action == 'types') {
      await widget.onConfigureTypes!();
      return;
    }
    if (action == 'defaults') {
      await widget.onDefaultSettings!();
      return;
    }
    setState(() {
      if (action == 'selected') {
        _selectedOnly = !_selectedOnly;
        _selectedFilterModels.clear();
        if (_selectedOnly) _selectedFilterModels.addAll(_selected);
      } else {
        _useAll = !_useAll;
        if (_useAll) {
          _selectedOnly = false;
          _selectedFilterModels.clear();
        }
        _changed = true;
      }
    });
  }

  Future<void> _openModel(String model) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ModelDetailPage(
        controller: widget.controller,
        service: widget.config.service,
        model: model,
        readOnly: true,
      ),
    ),
  );

  Widget _saveAction() => RoundAction(
    label: '保存',
    icon: Icons.check_rounded,
    onPressed: _canSave ? _saveSelection : null,
    iconWidget: SettingsIcon(
      type: SettingsIconType.check,
      color: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: _canSave ? 1 : .3),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = widget.selectable || _useAll
        ? {
            ...widget.config.savedModels,
            ..._models,
            ..._selected,
            ..._selectedFilterModels,
          }
        : widget.config.savedModels.toSet();
    final query = _search.text.trim().toLowerCase();
    final shown = available.where((model) {
      if (widget.selectable &&
          _selectedOnly &&
          !_useAll &&
          !_selectedFilterModels.contains(model)) {
        return false;
      }
      final name = widget.config.displayModel(model);
      return model.toLowerCase().contains(query) ||
          widget.config.apiModelFor(model).toLowerCase().contains(query) ||
          name.toLowerCase().contains(query);
    }).toList();
    final content = SearchSheetBody(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 108),
                child: Center(
                  child: Text(
                    '模型',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (widget.selectable)
                  GlassSurface(
                    radius: 28,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _saveAction(),
                        SizedBox(
                          height: 18,
                          child: VerticalDivider(
                            width: 1,
                            color: colors.outlineVariant,
                          ),
                        ),
                        Builder(
                          builder: (anchor) => RoundAction(
                            label: '更多',
                            icon: Icons.filter_list_rounded,
                            iconWidget: const SettingsIcon(
                              type: SettingsIconType.more,
                            ),
                            onPressed: _loaded && !_fetching
                                ? () => _showFilter(anchor, shown)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.onConfigureTypes != null ||
                    widget.onDefaultSettings != null)
                  Builder(
                    builder: (anchor) => SettingsGlassAction(
                      label: '更多',
                      icon: Icons.more_vert,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.more,
                      ),
                      onPressed: () => _showFilter(anchor, shown),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
      child: FloatingSearchLayout(
        controller: _search,
        onChanged: (_) => setState(() {}),
        hintText: '搜索模型',
        enabled: !(widget.selectable && !_useAll) && available.length >= 20,
        child: _fetching && !_loaded
            ? const ModelListSkeleton(
                padding: EdgeInsets.fromLTRB(20, 68, 20, 80),
              )
            : CustomScrollView(
                slivers: [
                  if (shown.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: EmptyDataView(
                            title:
                                widget.selectable &&
                                    _selectedOnly &&
                                    query.isEmpty &&
                                    shown.isEmpty
                                ? '暂无已选模型'
                                : _models.isNotEmpty
                                ? '没有匹配的模型'
                                : !widget.selectable && !_useAll
                                ? '暂无已选模型，请编辑供应商添加'
                                : widget.config.apiKey.isEmpty
                                ? '请返回供应商页配置 API 密钥'
                                : '暂无可用模型，请返回检查供应商配置',
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        68,
                        12,
                        widget.selectable && !_useAll
                            ? 80
                            : available.length >= 20
                            ? FloatingSearchLayout.clearance
                            : 16,
                      ),
                      sliver: SliverList.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, index) {
                          final model = shown[index];
                          final selected = _selected.contains(model);
                          return Theme(
                            data: Theme.of(context).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              highlightColor: Colors.transparent,
                            ),
                            child: Semantics(
                              checked: widget.selectable && !_useAll
                                  ? selected
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                ),
                                leading: widget.selectable && !_useAll
                                    ? Container(
                                        width: 22,
                                        height: 22,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? colors.onSurface
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: selected
                                                ? colors.onSurface
                                                : colors.outline,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: selected
                                            ? SettingsIcon(
                                                type: SettingsIconType.check,
                                                color: colors.surface,
                                              )
                                            : null,
                                      )
                                    : null,
                                title: Text(
                                  widget.config.displayModel(model),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                subtitle: _loaded && !_models.contains(model)
                                    ? const Text('未在当前列表中')
                                    : null,
                                trailing: widget.selectable
                                    ? null
                                    : const SettingsIcon(
                                        type: SettingsIconType.chevron,
                                      ),
                                onTap:
                                    widget.selectable &&
                                        !_useAll &&
                                        _loaded &&
                                        !_fetching
                                    ? () => _toggle(model)
                                    : widget.selectable
                                    ? null
                                    : () => _openModel(model),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .8,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (widget.selectable && !_useAll)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: ModelSelectionBar(
                    search: _search,
                    onSearchChanged: (_) => setState(() {}),
                    selectedCount: _selected.length,
                    totalCount: available.length,
                    allSelected:
                        shown.isNotEmpty && shown.every(_selected.contains),
                    onSelectAll: !_loaded || _fetching || shown.isEmpty
                        ? null
                        : () => _selectBatch(shown),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
