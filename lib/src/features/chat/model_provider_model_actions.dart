part of 'model_provider_detail.dart';

extension _ProviderModelActions on _ModelProviderDetailState {
  Future<void> _openModelManagement() async {
    await _openModelSettings(
      ProviderModelManagementPage(
        controller: widget.controller,
        service: _service,
        readOnly: true,
        onConfigureTypes: _configureModelTypes,
      ),
    );
  }

  Future<void> _openWebsite() async {
    final uri = Uri.tryParse(_website.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _notice('请填写有效的 HTTPS 官网地址');
      return;
    }
    try {
      await AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': uri.toString(),
      });
    } catch (_) {
      if (mounted) _notice('无法打开官网，请稍后重试', kind: ToastKind.error);
    }
  }

  Future<bool> _configureModelTypes() async {
    final result = await Navigator.push<ModelTypeSettings>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ModelTypeRecognitionPage(config: _draft, readOnly: !_editing),
      ),
    );
    if (!mounted || result == null) return false;
    _modelTypeMappings = result.mappings;
    _modelPurposeField.text = result.path;
    if (_editing) {
      _modelDraft.updateDetails({
        'modelPurposeField': result.path,
        'modelTypeMappings': {
          for (final entry in result.mappings.entries)
            entry.key: entry.value.name,
        },
      });
    }
    _changed();
    return true;
  }
}
