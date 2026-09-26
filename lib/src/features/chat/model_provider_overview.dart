part of 'model_provider_detail.dart';

const _providerTileShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(20)),
);

extension _ProviderOverview on _ModelProviderDetailState {
  Widget _overview() {
    return ListView(
      padding: settingsPagePadding(
        context,
        const EdgeInsets.fromLTRB(12, 12, 12, 32),
      ),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: ModelProviderIcon(config: _saved),
          title: const Text('供应商名称'),
          subtitle: Text(_saved.displayName),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('接口协议'),
          subtitle: Text(_saved.protocol.label),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('API 密钥'),
          subtitle: _overviewValue(
            _saved.apiKey.isEmpty ? '未配置' : '已配置',
            unset: _saved.apiKey.isEmpty,
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('服务地址'),
          subtitle: SelectableText(_saved.baseUrl),
        ),
        if (_saved.isConfigured)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text('可用模型'),
            shape: _providerTileShape,
            subtitle: Text(
              _saved.autoSyncModels
                  ? '默认全部'
                  : '已选 ${_saved.savedModels.length} 个模型',
            ),
            trailing: const SettingsIcon(type: SettingsIconType.chevron),
            onTap: _openModelManagement,
          ),
        ListTile(
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('默认模型设置'),
          shape: _providerTileShape,
          subtitle: const Text('此供应商下的模型默认继承，可单独覆盖'),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: _openDefaultModelSettings,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('官网地址'),
          shape: _providerTileShape,
          subtitle: _overviewValue(
            _saved.website.isEmpty ? '未设置' : _saved.website,
            unset: _saved.website.isEmpty,
          ),
          trailing: _saved.website.isEmpty
              ? null
              : const SettingsIcon(type: SettingsIconType.chevron),
          onTap: _saved.website.isEmpty ? null : _openWebsite,
        ),
        if (_saved.isConfigured) ...[
          const SizedBox(height: 12),
          ModelBalanceTile(
            key: ValueKey(_service),
            config: _saved,
            overview: true,
          ),
        ],
      ],
    );
  }
}
