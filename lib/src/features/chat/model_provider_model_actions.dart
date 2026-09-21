part of 'model_provider_detail.dart';

extension _ProviderModelActions on _ModelProviderDetailState {
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
      if (mounted) _notice('无法打开官网，请稍后重试');
    }
  }

  Future<void> _openModelManagement() async {
    final selection =
        await showModalBottomSheet<({bool useAll, List<String> models})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: false,
          builder: (_) => ProviderModelsPage(
            config: _editing ? _draft : _saved,
            selectable: _editing,
          ),
        );
    if (!mounted || selection == null) return;
    _updateModelSelection(selection.useAll, selection.models);
  }
}
