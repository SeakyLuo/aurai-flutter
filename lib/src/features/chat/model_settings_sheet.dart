import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'header_action_menu.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
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
  List<ModelService>? _pendingOrder;
  bool _sorting = false;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final order = widget.controller.modelSettings.profiles.keys.toList();
    order.insert(newIndex, order.removeAt(oldIndex));
    setState(() => _pendingOrder = order);
    try {
      await widget.controller.reorderModelProviders(order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('排序保存失败：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
    }
  }

  bool _saved = false;
  bool _allowPop = false;

  Future<void> _openMore(BuildContext anchor) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: const [
        (
          value: 'add',
          label: '添加供应商',
          icon: SettingsIcon(type: SettingsIconType.add),
        ),
        (
          value: 'sort',
          label: '调整顺序',
          icon: SettingsIcon(type: SettingsIconType.sort),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'add') await _add();
    if (action == 'sort') setState(() => _sorting = true);
  }

  Future<void> _menu(ModelService service, BuildContext anchor) async {
    final colors = Theme.of(context).colorScheme;
    final configured = widget.controller.modelSettings
        .profile(service)
        .isConfigured;
    final action = await showHeaderActionMenu(
      anchor,
      destructiveValues: const {'clear', 'delete'},
      items: [
        (
          value: 'edit',
          label: '编辑',
          icon: ConversationMenuIcon(
            type: ConversationMenuIconType.rename,
            color: colors.onSurface,
          ),
        ),
        if (configured)
          (
            value: 'clear',
            label: '清除密钥',
            icon: ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
              color: colors.error,
            ),
          ),
        if (service.isCustom)
          (
            value: 'delete',
            label: '删除供应商',
            icon: ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
              color: colors.error,
            ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _open(service, editing: true);
      return;
    }
    final deleting = action == 'delete';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: deleting
            ? '删除“${widget.controller.modelSettings.profile(service).displayName}”？'
            : '清除“${widget.controller.modelSettings.profile(service).displayName}”的密钥？',
        description: deleting
            ? '将删除此供应商的配置和密钥。仍被模型或 AI 使用时，需要先更换供应商。'
            : '保留供应商配置，后续调用需要重新填写密钥。',
        confirmLabel: deleting ? '删除' : '清除密钥',
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await widget.controller.removeProviderConfiguration(
        service,
        delete: deleting,
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text(deleting ? '供应商已删除' : '密钥已清除')),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ModelProviderDetail(
          controller: widget.controller,
          service: ModelService.custom('新供应商'),
          accountOnly: true,
          credentialsOnly: true,
          creating: true,
        ),
      ),
    );
    if (mounted && saved == true) setState(() => _saved = true);
  }

  Future<void> _open(ModelService service, {bool editing = false}) async {
    final saved =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ModelProviderDetail(
              controller: widget.controller,
              service: service,
              editing: editing,
              accountOnly: widget.accountOnly,
              credentialsOnly: widget.accountOnly,
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
    if (_sorting) {
      setState(() => _sorting = false);
      return;
    }
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
            extendBodyBehindAppBar: true,
            appBar: SettingsAppBar(
              gradientBackground: true,
              title: _sorting
                  ? '供应商排序'
                  : widget.accountOnly
                  ? '模型供应商'
                  : '选择模型',
              onBack: _leave,
              actions: [
                if (_sorting)
                  SettingsGlassAction(
                    label: '完成排序',
                    icon: Icons.check_rounded,
                    iconWidget: const SettingsIcon(
                      type: SettingsIconType.check,
                    ),
                    onPressed: () => setState(() => _sorting = false),
                  )
                else
                  Builder(
                    builder: (anchor) => SettingsGlassAction(
                      label: '更多',
                      icon: Icons.more_horiz_rounded,
                      onPressed: _pendingOrder == null
                          ? () => _openMore(anchor)
                          : null,
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      onReorderItem: _reorder,
                      proxyDecorator: (child, index, animation) => child,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        View.of(context).padding.top /
                                View.of(context).devicePixelRatio +
                            76 +
                            16,
                        16,
                        32,
                      ),
                      itemCount:
                          widget.controller.modelSettings.profiles.length,
                      itemBuilder: (context, index) {
                        final service =
                            (_pendingOrder ??
                            widget.controller.modelSettings.profiles.keys
                                .toList())[index];
                        final settings = widget.controller.modelSettings;
                        final profile = settings.profile(service);
                        return Padding(
                          key: ValueKey(service.name),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Builder(
                            builder: (anchorContext) => Material(
                              color: settingsFieldColor(context),
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                leading: ModelProviderIcon(service: service),
                                title: Text(profile.displayName),
                                subtitle: Text(
                                  profile.isConfigured
                                      ? (widget.accountOnly
                                            ? '已配置'
                                            : profile.model.isEmpty
                                            ? '选择模型'
                                            : modelDisplayName(profile.model))
                                      : '未配置',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!widget.accountOnly &&
                                        settings.activeConfig.isConfigured &&
                                        settings.activeConfig.service ==
                                            service) ...[
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
                                    if (_sorting)
                                      ReorderableDragStartListener(
                                        index: index,
                                        enabled: _pendingOrder == null,
                                        child: const Tooltip(
                                          message: '拖动排序',
                                          child: SizedBox(
                                            width: 40,
                                            height: 48,
                                            child: Center(
                                              child: SettingsIcon(
                                                type: SettingsIconType.drag,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      const SettingsIcon(
                                        type: SettingsIconType.chevron,
                                      ),
                                  ],
                                ),
                                onTap: !_sorting && _pendingOrder == null
                                    ? () => _open(service)
                                    : null,
                                onLongPress: !_sorting && _pendingOrder == null
                                    ? () => _menu(service, anchorContext)
                                    : null,
                              ),
                            ),
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
