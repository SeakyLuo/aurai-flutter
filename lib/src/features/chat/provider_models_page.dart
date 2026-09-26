import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'model_detail_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'question_icon.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'model_search_field.dart';

class ProviderModelsPage extends StatefulWidget {
  const ProviderModelsPage({
    super.key,
    required this.controller,
    required this.config,
    this.selectable = false,
  });
  final ChatController controller;
  final ModelConfig config;
  final bool selectable;
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

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _catalog?.close();
    _search.dispose();
    super.dispose();
  }

  bool _canConnect() {
    if (widget.config.apiKey.isEmpty) {
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
    if (!widget.selectable && !widget.config.autoSyncModels) {
      setState(() {
        _models = widget.config.savedModels;
        _selected
          ..clear()
          ..addAll(_models);
        _loaded = true;
        _fetching = false;
      });
      return;
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
            _selected.addAll(_useAll ? models : widget.config.savedModels);
          }
          _loaded = true;
          _requestFailed = false;
        });
    } on ModelProviderException catch (error) {
      _requestFailed = true;
      if (mounted) _notice(error.message);
    } catch (_) {
      _requestFailed = true;
      if (mounted) _notice('读取模型失败，请下拉重试或返回检查供应商配置');
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
      _notice('请至少选择一个模型');
      return;
    }
    Navigator.pop(context, (useAll: _useAll, models: _selected.toList()));
  }

  Future<void> _showFilter(BuildContext anchor) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        if (!_useAll)
          (
            value: 'selected',
            label: _selectedOnly ? '显示全部模型' : '只看已选模型',
            icon: const SettingsIcon(type: SettingsIconType.check),
          ),
        (
          value: 'useAll',
          label: _useAll ? '关闭使用全部' : '使用全部模型',
          icon: const SettingsIcon(type: SettingsIconType.miniapps),
        ),
      ],
    );
    if (!mounted || action == null) return;
    setState(() {
      if (action == 'selected') {
        _selectedOnly = !_selectedOnly;
      } else {
        _useAll = !_useAll;
        if (_useAll) _selectedOnly = false;
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
    final query = _search.text.trim().toLowerCase();
    final available = widget.selectable || _useAll
        ? {
            ..._models,
            if (!widget.config.autoSyncModels) ...widget.config.savedModels,
            ..._selected,
          }
        : widget.config.savedModels.toSet();
    final shown = available.where((model) {
      if (widget.selectable &&
          _selectedOnly &&
          !_useAll &&
          !_selected.contains(model)) {
        return false;
      }
      final name = widget.config.protocol.displayModel(model);
      return model.toLowerCase().contains(query) ||
          name.toLowerCase().contains(query);
    }).toList();
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              SettingsGlassAction(
                label: '关闭',
                icon: Icons.close_rounded,
                iconWidget: const QuestionIcon(type: QuestionIconType.close),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  !_loaded
                      ? '可用模型'
                      : widget.selectable && _selectedOnly && !_useAll
                      ? '已选模型（${_selected.length}）'
                      : '可用模型（${available.length}）',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.selectable)
                GlassSurface(
                  radius: 28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (anchor) => RoundAction(
                          label: '筛选模型',
                          icon: Icons.filter_list_rounded,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.filter,
                          ),
                          onPressed: _loaded && !_fetching
                              ? () => _showFilter(anchor)
                              : null,
                        ),
                      ),
                      SizedBox(
                        height: 18,
                        child: VerticalDivider(
                          width: 1,
                          color: colors.outlineVariant,
                        ),
                      ),
                      _saveAction(),
                    ],
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ModelSearchField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            hintText: '搜索模型',
          ),
        ),
        Expanded(
          child: _fetching && !_loaded
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  notificationPredicate: (_) => widget.selectable || _useAll,
                  onRefresh: _fetch,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (shown.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
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
                                    : '暂无可用模型，可下拉重试或返回检查供应商配置',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            widget.selectable && !_useAll ? 72 : 16,
                          ),
                          sliver: SliverList.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, index) {
                              final model = shown[index];
                              final selected = _selected.contains(model);
                              return Semantics(
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
                                    widget.config.protocol.displayModel(model),
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
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
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
                  child: GlassSurface(
                    radius: 26,
                    tintOpacity: .65,
                    shadowOpacity: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 16, 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _useAll && _loaded && !_requestFailed
                                  ? '已选全部'
                                  : '已选 ${_selected.length} 个模型',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: !_loaded || _fetching || shown.isEmpty
                                ? null
                                : () => _selectBatch(shown),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.onSurface,
                            ),
                            child: Text(
                              shown.isNotEmpty &&
                                      shown.every(_selected.contains)
                                  ? query.isEmpty
                                        ? '取消全选'
                                        : '取消选择搜索结果'
                                  : query.isEmpty
                                  ? '全选'
                                  : '全选搜索结果',
                            ),
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
    );
  }
}
