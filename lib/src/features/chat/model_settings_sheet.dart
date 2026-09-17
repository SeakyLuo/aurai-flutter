import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'model_provider_detail.dart';
import 'model_provider_icon.dart';

class ModelSettingsSheet extends StatefulWidget {
  const ModelSettingsSheet({
    super.key,
    required this.controller,
    required this.continueAfterSave,
    this.accountOnly = false,
    this.initialService,
  });
  final ChatController controller;
  final bool continueAfterSave;
  final bool accountOnly;
  final ModelService? initialService;
  static Future<bool> show(
    BuildContext context, {
    required ChatController controller,
    required bool continueAfterSave,
    bool accountOnly = false,
    ModelService? initialService,
  }) async {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ModelSettingsSheet(
              controller: controller,
              continueAfterSave: continueAfterSave,
              accountOnly: accountOnly,
              initialService: initialService,
            ),
          ),
        ) ??
        false;
  }

  @override
  State<ModelSettingsSheet> createState() => _ModelSettingsSheetState();
}

class _ModelSettingsSheetState extends State<ModelSettingsSheet> {
  bool _saved = false;
  bool _allowPop = false;

  Future<void> _open(ModelService service) async {
    final saved =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ModelProviderDetail(
              controller: widget.controller,
              service: service,
              accountOnly: widget.accountOnly,
            ),
          ),
        ) ??
        false;
    if (!mounted) return;
    setState(() => _saved = _saved || saved);
    if (widget.initialService != null || (saved && widget.continueAfterSave))
      _leave();
  }

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _saved);
    });
  }

  @override
  Widget build(BuildContext context) => widget.initialService != null
      ? ModelProviderDetail(
          controller: widget.controller,
          service: widget.initialService!,
          accountOnly: widget.accountOnly,
        )
      : PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            appBar: SettingsAppBar(title: '模型设置', onBack: _leave),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: ModelService.values.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final service = ModelService.values[index];
                        final settings = widget.controller.modelSettings;
                        final profile = settings.profile(service);
                        return Material(
                          color: settingsFieldColor(context),
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            leading: ModelProviderIcon(service: service),
                            title: Text(service.label),
                            subtitle: Text(
                              profile.isConfigured
                                  ? modelDisplayName(profile.model)
                                  : '未配置',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (settings.activeService == service) ...[
                                  Text(
                                    '默认',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                const SettingsIcon(
                                  type: SettingsIconType.chevron,
                                ),
                              ],
                            ),
                            onTap: () => _open(service),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}
