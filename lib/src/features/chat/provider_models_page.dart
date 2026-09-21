import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'question_icon.dart';
import 'glass_surface.dart';

class ProviderModelsPage extends StatefulWidget {
  const ProviderModelsPage({
    super.key,
    required this.config,
    this.selectable = false,
  });
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
    if (!_canConnect()) {
      setState(() => _fetching = false);
      return;
    }
    setState(() => _fetching = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.load(
        baseUrl: Uri.parse(widget.config.baseUrl),
        apiKey: widget.config.apiKey,
        openRouter: widget.config.service == ModelService.openRouter,
        textOnly: false,
      );
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

  void _saveSelection() =>
      Navigator.pop(context, (useAll: _useAll, models: _selected.toList()));

  Widget _saveAction() => SettingsGlassAction(
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
    final available = {
      ..._models,
      if (!widget.config.autoSyncModels) ...widget.config.savedModels,
      ..._selected,
    };
    final shown = available
        .where((model) => model.toLowerCase().contains(query))
        .toList();
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
                  _loaded ? '可用模型（${available.length}）' : '可用模型',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.selectable)
                _saveAction()
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        if (widget.selectable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text('使用全部', style: TextStyle(fontSize: 16)),
                ),
                Switch.adaptive(
                  value: _useAll,
                  onChanged: widget.selectable && _loaded && !_fetching
                      ? (useAll) => setState(() {
                          _useAll = useAll;
                          _changed = true;
                        })
                      : null,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索模型',
              filled: true,
              fillColor: settingsFieldColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _fetching && !_loaded
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
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
                                _models.isNotEmpty
                                    ? '没有匹配的模型'
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
                            16,
                            0,
                            16,
                            widget.selectable && !_useAll ? 72 : 16,
                          ),
                          sliver: SliverList.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, index) {
                              final model = shown[index];
                              final selected = _selected.contains(model);
                              return Semantics(
                                checked: _useAll ? null : selected,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  visualDensity: const VisualDensity(
                                    vertical: -2,
                                  ),
                                  leading: !_useAll
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
                                    model,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  subtitle: _loaded && !_models.contains(model)
                                      ? const Text('未在当前列表中')
                                      : null,
                                  onTap:
                                      widget.selectable &&
                                          !_useAll &&
                                          _loaded &&
                                          !_fetching
                                      ? () => _toggle(model)
                                      : null,
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
