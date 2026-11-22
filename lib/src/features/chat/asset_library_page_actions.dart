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
        if (mounted) await _load(refresh: true);
      case 'clear':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => const DeleteConfirmationDialog(
            title: '清空回收站？',
            description: '回收站中的所有资料将彻底删除，无法恢复。已发送的聊天附件会保留。',
            confirmLabel: '清空',
          ),
        );
        if (confirmed != true || !mounted) return;
        await _mutate(_library.clearTrash);
        if (mounted) _notice('回收站已清空', kind: ToastKind.success);
    }
  }

  Future<LibraryAsset?> _assetMenu(
    BuildContext buttonContext,
    LibraryAsset asset, {
    Offset? position,
    VoidCallback? closePreview,
  }) async {
    final action = await showAssetActionsMenu(
      buttonContext,
      position: position,
      canLocate: asset.conversationId != null && asset.messageId != null,
      canManageAsset: true,
      trash: widget.trash,
    );
    if (!mounted) return null;
    switch (action) {
      case 'forward':
        await _forward(buttonContext, [asset]);
      case 'rename':
        return _rename(asset);
      case 'save':
        await _save(asset);
      case 'restore':
        await _restore([asset.id]);
        closePreview?.call();
      case 'delete':
        await _delete([asset.id], onDeleted: closePreview);
      case 'locate':
        closePreview?.call();
        await openHomeConversation(
          context,
          widget.controller,
          asset.conversationId!,
          messageId: asset.messageId!,
        );
      case 'info':
        await showAssetInfo(buttonContext, asset);
    }
    return null;
  }

  Future<void> _open(LibraryAsset asset) async {
    if (!asset.isImage) {
      await MessageFileStore.open(asset.file);
      return;
    }
    final provider = localImageProvider(asset.path);
    final Size size;
    try {
      size = await loadPreviewImageSize(provider, context);
    } on PathNotFoundException {
      return;
    }
    if (!mounted) return;
    var currentAsset = asset;
    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => ImageActionScope(
          controller: widget.controller,
          child: ImagePreview(
            images: [provider],
            initialIndex: 0,
            heroTag: 'library-asset:${asset.id}',
            imageSize: size,
            onActions: (previewContext, index, position) => _perform(() async {
              final renamed = await _assetMenu(
                previewContext,
                currentAsset,
                position: position,
                closePreview: () {
                  if (previewContext.mounted &&
                      ModalRoute.of(previewContext)!.isCurrent) {
                    Navigator.pop(previewContext);
                  }
                },
              );
              if (renamed != null) currentAsset = renamed;
            }),
          ),
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeInOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Future<LibraryAsset?> _rename(LibraryAsset asset) async {
    final name = await showAssetRename(context, asset.name);
    if (name == null || !mounted) return null;
    await _mutate(() => _library.rename(asset, name));
    if (mounted) _notice('已重命名', kind: ToastKind.success);
    return LibraryAsset(
      id: asset.id,
      name: name,
      mimeType: asset.mimeType,
      kind: asset.kind,
      size: asset.size,
      source: asset.source,
      createdAt: asset.createdAt,
      path: asset.path,
      conversationId: asset.conversationId,
      messageId: asset.messageId,
    );
  }

  Future<void> _save(LibraryAsset asset, {bool notify = true}) async {
    await _library.download(asset);
    if (mounted && notify) _notice('已保存到应用下载目录', kind: ToastKind.success);
  }

  Future<void> _delete(List<String> ids, {VoidCallback? onDeleted}) async {
    final confirmed = widget.trash
        ? await showDialog<bool>(
            context: context,
            builder: (_) => DeleteConfirmationDialog(
              title: '彻底删除 ${ids.length} 项资料？',
              description: '彻底删除后无法恢复。已发送的聊天附件会保留。',
              confirmLabel: '彻底删除',
            ),
          )
        : await confirmAssetTrash(context, ids.length);
    if (confirmed != true || !mounted) return;
    await _mutate(
      () => widget.trash ? _library.purge(ids) : _library.moveToTrash(ids),
    );
    if (!mounted) return;
    onDeleted?.call();
    if (widget.trash) {
      _notice('已彻底删除', kind: ToastKind.success);
      return;
    }
    showAssetTrashed(
      ScaffoldMessenger.of(context),
      () => mounted
          ? _mutate(() => _library.restore(ids))
          : _library.restore(ids),
    );
  }

  Future<void> _restore(List<String> ids) async {
    await _mutate(() => _library.restore(ids));
    if (mounted) _notice('已恢复到资料库', kind: ToastKind.success);
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
      await _load(refresh: true);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _forwardSelected() async {
    final assets = _items
        .where((asset) => _selected.contains(asset.id))
        .toList();
    if (widget.picking) {
      Navigator.pop(context, assets);
      return;
    }
    final sent = await _forward(context, assets);
    if (sent && mounted) _closeSelection();
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
      if (mounted)
        _notice('已保存 ${assets.length} 项到应用下载目录', kind: ToastKind.success);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<bool> _forward(
    BuildContext originContext,
    List<LibraryAsset> assets,
  ) async {
    final controller = widget.controller;
    final sent = await Navigator.push<bool>(
      originContext,
      MaterialPageRoute(
        builder: (_) => assets.length == 1 && assets.single.isImage
            ? ImageForwardPage(
                controller: controller,
                image: localImageProvider(assets.single.path),
              )
            : ImageForwardPage.message(
                controller: controller,
                pageTitle: '转发资料',
                message: AgentMessage(
                  id: newMessageId(),
                  role: AgentMessageRole.user,
                  senderId: MessageSender.localUser.id,
                  text: '',
                  images: [
                    for (final asset in assets)
                      if (asset.isImage) asset.image,
                  ],
                  files: [
                    for (final asset in assets)
                      if (!asset.isImage) asset.file,
                  ],
                  createdAt: DateTime.now(),
                ),
              ),
      ),
    );
    if (sent == true && mounted) _notice('已转发', kind: ToastKind.success);
    return sent == true;
  }

  void _notice(String message, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(message)), kind: kind);
}
