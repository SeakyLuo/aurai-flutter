part of 'asset_library_page.dart';

extension _AssetLibraryPageActions on _AssetLibraryPageState {
  Future<void> _moreMenu(BuildContext buttonContext) async {
    final action = await showHeaderActionMenu(
      buttonContext,
      selectedValues: {(_grid ?? _type == AssetType.image) ? 'grid' : 'list'},
      separatorBeforeValues: {
        if (!widget.picking) 'grid',
        'sort',
        'trash',
        'clear',
      },
      items: [
        if (!widget.picking)
          (
            value: 'select',
            label: '批量选择',
            icon: const SettingsIcon(type: SettingsIconType.selectCircle),
          ),
        (
          value: 'grid',
          label: '网格',
          icon: const SettingsIcon(type: SettingsIconType.grid),
        ),
        (
          value: 'list',
          label: '列表',
          icon: const SettingsIcon(type: SettingsIconType.list),
        ),
        (
          value: 'sort',
          label: '排序',
          icon: const SettingsIcon(type: SettingsIconType.sort),
        ),
        if (!widget.trash && !widget.picking)
          (
            value: 'trash',
            label: '回收站',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
            ),
          ),
        if (widget.trash)
          (
            value: 'clear',
            label: '清空回收站',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
            ),
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'grid':
        _update(() => _grid = true);
      case 'list':
        _update(() => _grid = false);
      case 'sort':
        final sort = await showAssetSort(context, _sort);
        if (sort == null || !mounted) return;
        _update(() => _sort = sort);
        await _load(reset: true);
      case 'select':
        _update(() => _selecting = true);
      case 'trash':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AssetLibraryPage(controller: widget.controller, trash: true),
          ),
        );
        if (mounted) await _load(reset: true);
      case 'clear':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => const DeleteConfirmationDialog(
            title: '清空回收站？',
            description: '回收站中的所有资产将彻底删除，无法恢复。已发送的聊天附件会保留。',
            confirmLabel: '清空',
          ),
        );
        if (confirmed != true || !mounted) return;
        await _mutate(_library.clearTrash);
        if (mounted) _notice('回收站已清空');
    }
  }

  Future<void> _assetMenu(
    BuildContext buttonContext,
    LibraryAsset asset,
  ) async {
    final action = await showHeaderActionMenu(
      buttonContext,
      destructiveValues: {'delete'},
      items: [
        if (widget.trash)
          (
            value: 'restore',
            label: '恢复',
            icon: const QuestionIcon(type: QuestionIconType.undo),
          )
        else ...[
          (value: 'use', label: '用于聊天', icon: const ConversationIcon()),
          (
            value: 'rename',
            label: '重命名',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.rename,
            ),
          ),
          (
            value: 'save',
            label: '保存到设备',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.download,
            ),
          ),
        ],
        (
          value: 'delete',
          label: widget.trash ? '彻底删除' : '删除',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'use':
        await _use([asset]);
      case 'rename':
        await _rename(asset);
      case 'save':
        await _save(asset);
      case 'restore':
        await _restore([asset.id]);
      case 'delete':
        await _delete([asset.id]);
    }
  }

  Future<void> _open(LibraryAsset asset) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailPage(
          asset: asset,
          controller: widget.controller,
          trash: widget.trash,
          onUse: () => _use([asset]),
          onSave: () => _save(asset),
          onRestore: () => _restore([asset.id]),
        ),
      ),
    );
  }

  Future<void> _rename(LibraryAsset asset) async {
    final name = await showAssetRename(context, asset.name);
    if (name == null || !mounted) return;
    await _mutate(() => _library.rename(asset, name));
    if (mounted) _notice('已重命名');
  }

  Future<void> _save(LibraryAsset asset, {bool notify = true}) async {
    final support = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${support.path}/downloads/${asset.id}',
    ).create(recursive: true);
    final name = asset.isImage && !asset.name.contains('.')
        ? '${asset.name}.${extensionFromMime(asset.mimeType)}'
        : asset.name;
    await File(asset.path).copy('${directory.path}/$name');
    if (mounted && notify) _notice('已保存到应用下载目录');
  }

  Future<void> _delete(List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: widget.trash
            ? '彻底删除 ${ids.length} 项资产？'
            : '删除 ${ids.length} 项资产？',
        description: widget.trash
            ? '彻底删除后无法恢复。已发送的聊天附件会保留。'
            : '资产将移入回收站，已发送的聊天附件会保留。',
        confirmLabel: widget.trash ? '彻底删除' : '移入回收站',
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(
      () => widget.trash ? _library.purge(ids) : _library.moveToTrash(ids),
    );
    if (!mounted) return;
    if (widget.trash) {
      _notice('已彻底删除');
      return;
    }
    ScaffoldMessenger.of(context).showGlassSnackBar(
      SnackBar(
        content: const Text('已移入回收站'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => _perform(() => _restore(ids)),
        ),
      ),
    );
  }

  Future<void> _restore(List<String> ids) async {
    await _mutate(() => _library.restore(ids));
    if (mounted) _notice('已恢复到资料库');
  }

  Future<void> _mutate(Future<void> Function() action) async {
    _update(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _update(() {
        _selected.clear();
        _selecting = false;
      });
      await _load(reset: true);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _useSelected() async {
    final assets = _items
        .where((asset) => _selected.contains(asset.id))
        .toList();
    if (widget.picking) {
      Navigator.pop(context, assets);
      return;
    }
    await _use(assets);
  }

  Future<void> _saveSelected() async {
    final assets = _items
        .where((asset) => _selected.contains(asset.id))
        .toList();
    _update(() => _busy = true);
    try {
      for (final asset in assets) {
        await _save(asset, notify: false);
      }
      if (mounted) _notice('已保存 ${assets.length} 项到应用下载目录');
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _use(List<LibraryAsset> assets) async {
    final controller = widget.controller;
    final target = await Navigator.push<Conversation>(
      context,
      MaterialPageRoute(
        builder: (_) => AssetChatPicker(controller: controller),
      ),
    );
    if (target == null || !mounted) return;
    _update(() => _busy = true);
    try {
      await controller.selectConversation(target.id);
      await controller.addLibraryAssets(assets);
      if (!mounted) return;
      await openHomeConversation(context, controller, target.id);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));
}
