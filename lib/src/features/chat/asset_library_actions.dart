part of 'chat_controller.dart';

extension AssetLibraryActions on ChatController {
  AssetLibrary get assetLibrary =>
      AssetLibrary(_store.database, _imageStore.directory);

  Future<void> addLibraryAssets(
    List<LibraryAsset> assets, {
    Conversation? target,
  }) => _inConversation(target ?? activeConversation, () async {
    if (!canEditDraft) throw StateError('当前聊天暂时无法添加附件');
    final current = {
      ...draftImages.map((image) => image.path),
      ...draftFiles.map((file) => file.path),
    };
    final images = assets
        .where((asset) => asset.isImage && !current.contains(asset.path))
        .map((asset) => asset.image)
        .toList();
    final files = assets
        .where((asset) => !asset.isImage && !current.contains(asset.path))
        .map((asset) => asset.file)
        .toList();
    if (draftImages.length + images.length > MessageImageStore.maxImages)
      throw StateError('每条消息最多添加 4 张图片');
    if (draftFiles.length + files.length > MessageFileStore.maxFiles)
      throw StateError('每条消息最多添加 10 个文件');
    final conversation = activeConversation;
    _execution.attachmentJobs++;
    notifyListeners();
    var saved = false;
    try {
      draftImages.addAll(images);
      draftFiles.addAll(files);
      await _store.writer.save(
        conversation,
        makeActive: false,
        saveDraft: true,
        saveMessages: false,
      );
      if (identical(conversation, _newConversation)) await _storeNewDraft();
      saved = true;
    } finally {
      if (!saved) {
        conversation.draftImages.removeWhere(images.contains);
        conversation.draftFiles.removeWhere(files.contains);
      }
      _execution.attachmentJobs--;
      _conversationChanged();
    }
  });

  Future<void> _removeUnreferencedAttachments(Iterable<String> paths) async {
    final removable = await AssetLibrary.unreferencedPaths(
      _store.database,
      paths,
    );
    for (final path in removable) {
      await File(path).delete();
    }
  }
}
