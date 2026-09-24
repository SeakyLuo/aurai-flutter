part of 'model_provider_detail.dart';

extension _ProviderOverview on _ModelProviderDetailState {
  Widget _overview() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    children: [
      _readLabel('供应商名称', first: true),
      _readSurface(
        Row(
          children: [
            ModelProviderIcon(service: _service),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                _saved.displayName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      _readLabel('官网地址'),
      _readSurface(
        Row(
          children: [
            Expanded(
              child: Text(
                _saved.website.isEmpty ? '未设置' : _saved.website,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            if (_saved.website.isNotEmpty) ...[
              const SizedBox(width: 12),
              const SettingsIcon(type: SettingsIconType.chevron),
            ],
          ],
        ),
        onTap: _saved.website.isEmpty ? null : _openWebsite,
      ),
      _readValue('接口协议', _saved.protocol.label),
      _readValue('API 密钥', _saved.apiKey.isEmpty ? '未配置' : '已配置'),
      _readValue('服务地址', _saved.baseUrl),
      _readLabel('可用模型'),
      _readSurface(
        Row(
          children: [
            Expanded(
              child: Text(
                _saved.autoSyncModels
                    ? '默认全部'
                    : '${_saved.savedModels.length} 个模型',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
        onTap: _openModelManagement,
      ),
      _readLabel('请求转换'),
      _readSurface(
        Row(
          children: [
            Expanded(
              child: Text(
                (_saved.details?.requestAdapters.isNotEmpty ?? false)
                    ? '已配置'
                    : '未设置',
              ),
            ),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
        onTap: _openRequestAdapters,
      ),
      _readValue('思考强度', _saved.reasoning.label),
      if (_saved.isConfigured) ...[
        _readLabel('账户余额'),
        ModelBalanceTile(key: ValueKey(_service), config: _saved),
      ],
    ],
  );

  Widget _readLabel(String title, {bool first = false}) => Padding(
    padding: EdgeInsets.fromLTRB(18, first ? 8 : 24, 18, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _readValue(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _readLabel(title),
      _readSurface(
        SelectableText(
          value,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    ],
  );

  Widget _readSurface(Widget child, {VoidCallback? onTap}) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: onTap == null
        ? Padding(padding: const EdgeInsets.all(18), child: child)
        : InkWell(
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(18), child: child),
          ),
  );
}
