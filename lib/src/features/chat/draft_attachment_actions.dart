part of 'chat_controller.dart';

extension DraftAttachmentActions on ChatController {
  Future<void> addImages([ImageSource? source]) =>
      _inConversation(activeConversation, () => _addImages(source));

  Future<void> _addImages(ImageSource? source) async {
    final picking = source != null;
    _execution.attachmentJobs++;
    notifyListeners();
    try {
      if (picking)
        await _store.writer.save(
          activeConversation,
          makeActive: false,
          saveDraft: true,
          saveMessages: false,
        );
      final remaining = MessageImageStore.maxImages - draftImages.length;
      final images = source == null
          ? await _imageStore.recover(remaining)
          : await _imageStore.pick(source, remaining);
      if (images.isEmpty) return;
      draftImages.addAll(images);
      try {
        await _store.writer.save(
          activeConversation,
          makeActive: false,
          saveDraft: true,
          saveMessages: false,
        );
        if (identical(activeConversation, _newConversation)) {
          await _storeNewDraft();
        }
      } on Object {
        draftImages.removeWhere(images.contains);
        await _imageStore.remove(images);
        rethrow;
      }
    } finally {
      _execution.attachmentJobs--;
      _updateConversationList(activeConversation);
      notifyListeners();
    }
  }

  Future<void> removeDraftImage(MessageImage image) =>
      _inConversation(activeConversation, () => _removeDraftImage(image));

  Future<void> _removeDraftImage(MessageImage image) async {
    await DraftAttachmentCleanup(_store.database, _imageStore.directory).remove(
      image.path,
      activeConversation.defaultSenderId,
      () async {
        final index = draftImages.indexOf(image);
        draftImages.removeAt(index);
        notifyListeners();
        try {
          await _store.writer.save(
            activeConversation,
            makeActive: false,
            saveDraft: true,
            saveMessages: false,
          );
        } on Object {
          draftImages.insert(index, image);
          notifyListeners();
          rethrow;
        }
      },
    );
    await _removeEmptyDraft();
  }

  Future<List<MessageFile>> pickFiles(int remaining) =>
      MessageFileStore.pick(_imageStore.directory, remaining);

  Future<void> addFiles() => _inConversation(activeConversation, _addFiles);

  Future<void> _addFiles() async {
    _execution.attachmentJobs++;
    notifyListeners();
    try {
      await _store.writer.save(
        activeConversation,
        makeActive: false,
        saveDraft: true,
        saveMessages: false,
      );
      final files = await pickFiles(
        MessageFileStore.maxFiles - draftFiles.length,
      );
      draftFiles.addAll(files);
      try {
        await _store.writer.save(
          activeConversation,
          makeActive: false,
          saveDraft: true,
          saveMessages: false,
        );
        if (identical(activeConversation, _newConversation)) {
          await _storeNewDraft();
        }
      } on Object {
        draftFiles.removeWhere(files.contains);
        await MessageFileStore.remove(files);
        rethrow;
      }
    } finally {
      _execution.attachmentJobs--;
      _updateConversationList(activeConversation);
      notifyListeners();
    }
  }

  Future<void> removeDraftFile(MessageFile file) =>
      _inConversation(activeConversation, () => _removeDraftFile(file));

  Future<void> _removeDraftFile(MessageFile file) async {
    await DraftAttachmentCleanup(_store.database, _imageStore.directory).remove(
      file.path,
      activeConversation.defaultSenderId,
      () async {
        final index = draftFiles.indexOf(file);
        draftFiles.removeAt(index);
        notifyListeners();
        try {
          await _store.writer.save(
            activeConversation,
            makeActive: false,
            saveDraft: true,
            saveMessages: false,
          );
        } on Object {
          draftFiles.insert(index, file);
          notifyListeners();
          rethrow;
        }
      },
    );
    await _removeEmptyDraft();
  }
}
