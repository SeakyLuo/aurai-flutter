import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/image_generation_config.dart';
import '../../domain/model_provider.dart';
import '../../providers/image_generation_client.dart';
import '../../providers/model_catalog.dart';
import '../../providers/openrouter_models.dart';
import 'app_confirmation_dialog.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelReplacementPage extends StatefulWidget {
  const ModelReplacementPage({
    super.key,
    required this.controller,
    required this.purpose,
  });

  final ChatController controller;
  final ModelPurpose purpose;

  @override
  State<ModelReplacementPage> createState() => _ModelReplacementPageState();
}

class _ModelReplacementPageState extends State<ModelReplacementPage> {
  List<UsedModelSelection> _usedModels = const [];
  DefaultModelSelection? _from;
  ModelReplacementTarget? _to;
  ModelReplacementImpact? _scope;
  ModelReplacementImpact? _impact;
  ModelCatalog? _catalog;
  bool _loadingUsedModels = true;
  bool _loadingNewModels = false;
  bool _loadingImpact = false;
  bool _replacing = false;
  bool _noCandidates = false;
  int _impactRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadUsedModels();
  }

  @override
  void dispose() {
    _catalog?.close();
    super.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Future<void> _loadUsedModels() async {
    try {
      final results = await Future.wait<Object>([
        widget.controller.usedModels(widget.purpose),
        widget.controller.modelReplacementImpact(purpose: widget.purpose),
      ]);
      if (!mounted) return;
      setState(() {
        _usedModels = results[0] as List<UsedModelSelection>;
        _scope = results[1] as ModelReplacementImpact;
      });
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingUsedModels = false);
    }
  }

  String _key(DefaultModelSelection model) =>
      '${model.service.name}\n${model.model}';

  String _modelLabel(DefaultModelSelection model) =>
      '${widget.controller.modelSettings.profile(model.service).displayName} · ${model.name}';

  String _purposeLabel(ModelPurpose purpose) => switch (purpose) {
    ModelPurpose.text => '文本',
    ModelPurpose.imageGeneration => '图片生成',
    ModelPurpose.videoGeneration => '视频生成',
  };

  String get _allModelsLabel => widget.purpose == ModelPurpose.text
      ? '全部 AI 当前模型'
      : '全部${_purposeLabel(widget.purpose)}模型';

  String _impactSummary(ModelReplacementImpact impact) => [
    if (impact.aiCount > 0) '${impact.aiCount} 个 AI',
    for (final purpose in ModelPurpose.values)
      if (impact.purposes.contains(purpose))
        switch (purpose) {
          ModelPurpose.text => '默认文本模型',
          ModelPurpose.imageGeneration => '默认图片生成模型',
          ModelPurpose.videoGeneration => '默认视频生成模型',
        },
  ].join('、');

  bool get _sameModel =>
      _from != null &&
      _to != null &&
      _from!.service == _to!.model.service &&
      _from!.model == _to!.model.model;

  Future<void> _selectCurrentModel() async {
    final selected = await showChoiceSheet<String>(
      context,
      title: '当前模型',
      selected: _from == null ? '*' : _key(_from!),
      choices: [
        (value: '*', label: _allModelsLabel),
        for (final used in _usedModels)
          (
            value: _key(used.model),
            label:
                '${_modelLabel(used.model)} · ${_impactSummary(used.impact)}',
          ),
      ],
    );
    if (!mounted || selected == null) return;
    final from = selected == '*'
        ? null
        : _usedModels.firstWhere((used) => _key(used.model) == selected).model;
    setState(() {
      _from = from;
      _to = null;
      _scope = null;
      _impact = null;
      _noCandidates = false;
    });
    await _refreshScope();
  }

  Future<void> _refreshScope() async {
    final revision = ++_impactRevision;
    setState(() => _loadingImpact = true);
    try {
      final scope = await widget.controller.modelReplacementImpact(
        purpose: widget.purpose,
        from: _from,
      );
      if (mounted && revision == _impactRevision) {
        setState(() => _scope = scope);
      }
    } on Object catch (error) {
      if (mounted && revision == _impactRevision) _notice(errorMessage(error));
    } finally {
      if (mounted && revision == _impactRevision) {
        setState(() => _loadingImpact = false);
      }
    }
  }

  Future<void> _selectNewModel() async {
    final scope = _scope;
    if (scope == null || !scope.hasChanges) return;
    final accounts = widget.controller.modelSettings.profiles.values
        .where((profile) => profile.isConfigured)
        .toList();
    if (accounts.isEmpty) {
      _notice('请先配置可用的模型供应商');
      return;
    }
    final service = await showChoiceSheet<ModelService>(
      context,
      title: '选择新供应商',
      selected: _to?.model.service ?? accounts.first.service,
      choices: [
        for (final account in accounts)
          (value: account.service, label: account.displayName),
      ],
    );
    if (!mounted || service == null) return;
    setState(() {
      _to = null;
      _impact = null;
      _loadingNewModels = true;
      _noCandidates = false;
    });
    final catalog = ModelCatalog();
    final imageClient = ImageGenerationClient();
    _catalog = catalog;
    try {
      final targets = await _eligibleTargets(
        service: service,
        purpose: widget.purpose,
        catalog: catalog,
        imageClient: imageClient,
      );
      if (!mounted) return;
      if (targets.isEmpty) {
        setState(() => _noCandidates = true);
        return;
      }
      final selected = await showChoiceSheet<String>(
        context,
        title: '选择新模型',
        selected: _to?.model.service == service
            ? _to!.model.model
            : targets.first.model.model,
        choices: [
          for (final target in targets)
            (value: target.model.model, label: target.model.name),
        ],
      );
      if (!mounted || selected == null) return;
      setState(() {
        _to = targets.firstWhere((target) => target.model.model == selected);
      });
      await _refreshImpact();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      catalog.close();
      imageClient.close();
      _catalog = null;
      if (mounted) setState(() => _loadingNewModels = false);
    }
  }

  Future<List<ModelReplacementTarget>> _eligibleTargets({
    required ModelService service,
    required ModelPurpose purpose,
    required ModelCatalog catalog,
    required ImageGenerationClient imageClient,
  }) async {
    final account = widget.controller.modelSettings.profile(service);
    var generalModels = <String>[];
    if (purpose != ModelPurpose.imageGeneration) {
      generalModels =
          purpose == ModelPurpose.videoGeneration || account.autoSyncModels
          ? await catalog.load(
              baseUrl: Uri.parse(account.baseUrl),
              apiKey: account.apiKey,
              openRouter: service == ModelService.openRouter,
              textOnly: purpose == ModelPurpose.text,
            )
          : account.savedModels;
    }

    final imageModels = <String, ImageGenerationModel>{};
    if (purpose == ModelPurpose.imageGeneration) {
      if (service != ModelService.openRouter && service != ModelService.qwen) {
        return const [];
      }
      for (final model in await imageClient.models(account)) {
        imageModels[model.id] = model;
      }
    }

    final candidateIds = purpose == ModelPurpose.imageGeneration
        ? imageModels.keys.toList()
        : generalModels;
    final targets = <ModelReplacementTarget>[];
    for (final id in candidateIds) {
      final info = service == ModelService.openRouter
          ? OpenRouterModels.lookup(account.baseUrl, id)
          : null;
      final supportsText = info?.supportsText ?? true;
      final supportedPurposes = <ModelPurpose>{
        if (supportsText) ModelPurpose.text,
        if (imageModels.containsKey(id)) ModelPurpose.imageGeneration,
        if (info?.outputModalities.contains('video') ??
            purpose == ModelPurpose.videoGeneration)
          ModelPurpose.videoGeneration,
      };
      if (!supportedPurposes.contains(purpose)) continue;
      targets.add(
        ModelReplacementTarget(
          model: DefaultModelSelection(
            service: service,
            model: id,
            name: info?.name ?? imageModels[id]?.name ?? modelDisplayName(id),
          ),
          supportedPurposes: supportedPurposes,
          supportsText: supportsText,
          imageGeneration: imageModels[id],
        ),
      );
    }
    targets.sort((a, b) => a.model.name.compareTo(b.model.name));
    return targets;
  }

  Future<void> _refreshImpact() async {
    final to = _to;
    final revision = ++_impactRevision;
    if (to == null) {
      setState(() => _impact = null);
      return;
    }
    setState(() => _loadingImpact = true);
    try {
      final impact = await widget.controller.modelReplacementImpact(
        purpose: widget.purpose,
        from: _from,
        to: to.model,
      );
      if (mounted && revision == _impactRevision) {
        setState(() => _impact = impact);
      }
    } on Object catch (error) {
      if (mounted && revision == _impactRevision) _notice(errorMessage(error));
    } finally {
      if (mounted && revision == _impactRevision) {
        setState(() => _loadingImpact = false);
      }
    }
  }

  Future<void> _replace() async {
    final to = _to!;
    final impact = _impact!;
    final all = _from == null;
    final summary = _impactSummary(impact);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => AppConfirmationDialog(
        title: all ? '批量修改全部 AI 模型？' : '批量修改 AI 模型？',
        description: all
            ? '将把 $summary 当前使用的模型统一更换为“${_modelLabel(to.model)}”。默认文本模型不变。'
            : '将把使用“${_modelLabel(_from!)}”的 $summary 更换为“${_modelLabel(to.model)}”。默认文本模型不变。',
        confirmLabel: all ? '替换全部' : '更换模型',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _replacing = true);
    try {
      final result = await widget.controller.replaceModels(
        purpose: widget.purpose,
        from: _from,
        to: to,
      );
      if (mounted) Navigator.pop(context, result);
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  bool get _canReplace =>
      !_loadingUsedModels &&
      !_loadingNewModels &&
      !_loadingImpact &&
      !_replacing &&
      !_sameModel &&
      _to != null &&
      _impact?.hasChanges == true;

  String get _impactText {
    if (_loadingImpact) return '正在计算影响范围…';
    final scope = _scope;
    if (scope == null || !scope.hasChanges) return '当前没有需要更换的使用位置。';
    if (_to == null) return '将影响：${_impactSummary(scope)}。';
    if (_sameModel) return '新旧模型不能相同。';
    final impact = _impact;
    if (impact == null || !impact.hasChanges) return '当前没有需要更换的使用位置。';
    return '将更换：${_impactSummary(impact)}。';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '批量修改 AI 模型',
      onBack: _replacing ? null : () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: _from == null ? '替换全部' : '更换模型',
          icon: Icons.check_rounded,
          iconWidget: _replacing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const SettingsIcon(type: SettingsIconType.check),
          onPressed: _canReplace ? _replace : null,
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _label('当前模型'),
              _choice(
                _from == null ? _allModelsLabel : _modelLabel(_from!),
                _loadingUsedModels ||
                        _loadingNewModels ||
                        _loadingImpact ||
                        _replacing
                    ? null
                    : _selectCurrentModel,
                subtitle: '不指定具体模型时，将修改所有 AI 当前使用的模型',
                loading: _loadingUsedModels,
              ),
              const SizedBox(height: 16),
              _label('新模型'),
              _choice(
                _to == null ? '选择新模型' : _modelLabel(_to!.model),
                _loadingNewModels ||
                        _loadingUsedModels ||
                        _loadingImpact ||
                        _replacing
                    ? null
                    : _selectNewModel,
                loading: _loadingNewModels,
              ),
              if (_noCandidates) ...[
                const SizedBox(height: 12),
                _noCandidatesNotice(),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  _impactText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _noCandidatesNotice() => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    decoration: BoxDecoration(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '这个供应商没有可用的${_purposeLabel(widget.purpose)}模型，请选择其他供应商。',
          style: TextStyle(
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _choice(
    String title,
    VoidCallback? onTap, {
    String? subtitle,
    bool loading = false,
  }) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SettingsIcon(type: SettingsIconType.chevron),
      onTap: onTap,
    ),
  );
}
