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
        if (mounted) _notice('回收站已清空');
    }
  }

  Future<LibraryAsset?> _assetMenu(
    BuildContext buttonContext,
    LibraryAsset asset, {
    Offset? position,
    VoidCallback? closePreview,
  }) async {
    final action = await showHeaderActionMenu(
      buttonContext,
      position: position,
      destructiveValues: {'delete'},
      separatorBeforeValues: {if (!widget.trash) 'rename', 'delete'},
      items: [
        if (widget.trash)
          (
            value: 'restore',
            label: '恢复',
            icon: const QuestionIcon(type: QuestionIconType.undo),
          )
        else ...[
          (
            value: 'forward',
            label: '转发',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
            ),
          ),
          (
            value: 'save',
            label: '下载',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.download,
            ),
          ),
        ],
        if (asset.conversationId != null && asset.messageId != null)
          (
            value: 'locate',
            label: '定位消息',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.locate,
            ),
          ),
        if (!widget.trash)
          (
            value: 'rename',
            label: '重命名',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.rename,
            ),
          ),
        (
          value: 'info',
          label: '查看信息',
          icon: const SettingsIcon(type: SettingsIconType.info),
        ),
        (
          value: 'delete',
          label: widget.trash ? '彻底删除' : '移入回收站',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
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
    final size = await loadPreviewImageSize(provider, context);
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
    if (mounted) _notice('已重命名');
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
    final support = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${support.path}/downloads/${asset.id}',
    ).create(recursive: true);
    final name = asset.isImage && !asset.name.contains('.')
        ? '${asset.name}.${extensionFromMime(asset.mimeType)}'
        : asset.name;
    await File(asset.path).copy('${directory.path}/$name');
    if (mounted && notify) _notice('已保存到应用下载目录', kind: ToastKind.success);
  }

  Future<void> _delete(List<String> ids, {VoidCallback? onDeleted}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: widget.trash
            ? '彻底删除 ${ids.length} 项资料？'
            : '将 ${ids.length} 项资料移入回收站？',
        description: widget.trash
            ? '彻底删除后无法恢复。已发送的聊天附件会保留。'
            : '可在回收站中恢复。已发送的聊天附件会保留。',
        confirmLabel: widget.trash ? '彻底删除' : '移入回收站',
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(
      () => widget.trash ? _library.purge(ids) : _library.moveToTrash(ids),
    );
    if (!mounted) return;
    onDeleted?.call();
    if (widget.trash) {
      _notice('已彻底删除');
      return;
    }
    ScaffoldMessenger.of(context).showToast(
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
    if (sent == true && mounted) _notice('已转发');
    return sent == true;
  }

  void _notice(String message, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(message)), kind: kind);
}
