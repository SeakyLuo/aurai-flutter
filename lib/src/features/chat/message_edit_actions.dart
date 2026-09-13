part of 'chat_controller.dart';

extension MessageEditActions on ChatController {
  Future<List<MessageImage>> pickEditImages(
    ImageSource source,
    int remaining,
  ) => _imageStore.pick(source, remaining);

  Future<void> removeEditImages(Iterable<MessageImage> images) =>
      _imageStore.remove(images);

  Future<bool> editMessageAndPrepareReply(
    AgentMessage message,
    String text, {
    List<MessageImage>? images,
    List<MessageFile>? files,
  }) async {
    if (hasRunningTask ||
        isBusy ||
        addingImages ||
        changingConversation ||
        loadingEarlierMessages) {
      throw StateError('请等待当前操作完成，再编辑消息');
    }
    if (message.role != AgentMessageRole.user) {
      throw StateError('只能编辑自己的消息');
    }
    changingConversation = true;
    _conversationChanged();
    try {
      await _persist();
      final previous = activeConversation;
      final index = messages.indexWhere((item) => item.id == message.id);
      final edited = AgentMessage(
        id: message.id,
        role: message.role,
        text: text,
        createdAt: message.createdAt,
        images: images ?? message.images,
        files: files ?? message.files,
      );
      final replacement = conversationFromRow(conversationRow(previous))
        ..messages.addAll([...messages.take(index), edited])
        ..draftFiles.addAll(previous.draftFiles)
        ..draftImages.addAll(previous.draftImages)
        ..hasEarlierMessages = previous.hasEarlierMessages
        ..pendingGoal = text
        ..runState = ChatRunState.idle
        ..errorDetail = null
        ..activeRunId = null
        ..storedPreview = null;
      final removedImages = await _store.replaceFromMessage(
        replacement,
        message,
      );
      _activeConversation = replacement;
      _loadedMessageCounts[replacement.id] = replacement.messages.length;
      _updateConversationList();
      try {
        for (final path in removedImages) {
          await File(path).delete();
        }
        return true;
      } on FileSystemException {
        return false;
      }
    } finally {
      changingConversation = false;
      _conversationChanged();
    }
  }
}
