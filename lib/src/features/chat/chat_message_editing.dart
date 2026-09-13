part of 'chat_page.dart';

extension _ChatMessageEditing on _ChatPageState {
  Future<void> _beginMessageEdit(AgentMessage message) async {
    final controller = widget.controller;
    if (controller.hasRunningTask ||
        controller.isBusy ||
        controller.addingImages ||
        controller.changingConversation ||
        controller.loadingEarlierMessages ||
        _preparingGoal) {
      _imageNotice('请先结束当前操作，再编辑消息');
      return;
    }
    _draftTimer?.cancel();
    final session = MessageEditSession(
      message: message,
      bookmark: _scrollBookmarks[_conversationId],
      sentMessageId: _sentMessageId,
      followOutput: _followOutput,
      contentBelow: _contentBelow,
      draft: _textController.value,
    );
    _updateEditing(() {
      _editing = session;
      _textController.value = TextEditingValue(
        text: message.text,
        selection: TextSelection.collapsed(offset: message.text.length),
      );
      _sentMessageId = null;
      _followOutput = session.followOutput;
      _contentBelow = session.contentBelow;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_editing, session)) return;
      final bookmark = session.bookmark;
      if (bookmark != null) {
        _viewportKey.currentState?.restoreBookmark(
          ChatScrollBookmark(
            bookmark.messageId,
            bookmark.alignment,
            session.followOutput,
          ),
        );
      }
      _focusNode.requestFocus();
    });
  }

  void _restoreEditDraft(MessageEditSession session) {
    _textController.removeListener(_onTextChanged);
    _textController.value = session.draft;
    _textController.addListener(_onTextChanged);
    _canSend = session.draft.text.trim().isNotEmpty;
  }

  void _cancelMessageEdit() {
    final session = _editing!;
    if (session.saving || session.picking) return;
    _updateEditing(() {
      _restoreEditDraft(session);
      _editing = null;
      _sentMessageId = session.followOutput ? null : session.sentMessageId;
      _followOutput = session.followOutput;
      _contentBelow = session.contentBelow;
    });
    unawaited(_discardEditImages(session));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bookmark = session.bookmark;
      if (bookmark != null) {
        _viewportKey.currentState?.restoreBookmark(
          ChatScrollBookmark(
            bookmark.messageId,
            bookmark.alignment,
            session.followOutput,
            bookmark.replyAnchorId,
          ),
        );
      } else if (session.followOutput) {
        _scrollToBottom();
      }
    });
  }

  Future<void> _addEditImages(BuildContext buttonContext) async {
    final session = _editing!;
    if (session.saving || session.picking) return;
    _updateEditing(() => session.picking = true);
    try {
      final source = await showImageSourceMenu(buttonContext);
      if (source == null || !mounted || !identical(_editing, session)) return;
      if (source == AttachmentSource.file) {
        final remaining = MessageFileStore.maxFiles - session.files.length;
        if (remaining == 0) {
          _imageNotice('每条消息最多添加 10 个文件');
          return;
        }
        final files = await widget.controller.pickFiles(remaining);
        session.addedFiles.addAll(files);
        if (!mounted || !identical(_editing, session)) {
          await _discardEditImages(session);
          return;
        }
        _updateEditing(() => session.files.addAll(files));
        return;
      }
      final remaining = MessageImageStore.maxImages - session.images.length;
      if (remaining == 0) {
        _imageNotice('每条消息最多添加 4 张图片');
        return;
      }
      final images = await widget.controller.pickEditImages(
        source == AttachmentSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        remaining,
      );
      session.addedImages.addAll(images);
      if (!mounted || !identical(_editing, session)) {
        await _discardEditImages(session);
        return;
      }
      _updateEditing(() => session.images.addAll(images));
    } on Object catch (error) {
      if (mounted)
        _imageNotice(
          error is ImageInputException
              ? error.message
              : error is PlatformException
              ? error.message ?? '附件添加失败'
              : '附件添加失败，请重试',
        );
    } finally {
      if (mounted && identical(_editing, session))
        _updateEditing(() => session.picking = false);
    }
  }

  Future<void> _removeEditImage(MessageImage image) async {
    final session = _editing!;
    if (session.saving || session.picking) return;
    _updateEditing(() => session.images.remove(image));
  }

  Future<void> _discardEditImages(MessageEditSession session) async {
    final files = [...session.addedFiles];
    session.addedFiles.clear();
    final images = [...session.addedImages];
    session.addedImages.clear();
    try {
      await widget.controller.removeEditImages(images);
      await MessageFileStore.remove(files);
    } on Object {
      if (mounted) _imageNotice('部分临时图片清理失败');
    }
  }

  Future<void> _submitMessageEdit() async {
    final session = _editing!;
    final controller = widget.controller;
    if (session.saving ||
        session.picking ||
        (_textController.text.trim().isEmpty &&
            session.images.isEmpty &&
            session.files.isEmpty))
      return;
    if (controller.hasRunningTask ||
        controller.isBusy ||
        controller.addingImages ||
        controller.changingConversation ||
        controller.loadingEarlierMessages ||
        _preparingGoal) {
      _imageNotice('请先结束当前操作，再编辑消息');
      return;
    }
    _updateEditing(() => session.saving = true);
    try {
      final cleaned = await controller.editMessageAndPrepareReply(
        session.message,
        _textController.text.trim(),
        images: session.images,
        files: session.files,
      );
      // Committed images now belong to the message, even if the page closes.
      session.addedFiles.removeWhere(session.files.contains);
      session.addedImages.removeWhere(
        (image) => session.images.contains(image),
      );
      await _discardEditImages(session);
      if (!mounted || !identical(_editing, session)) return;
      _focusNode.unfocus();
      _updateEditing(() {
        _restoreEditDraft(session);
        _editing = null;
        _sentMessageId = session.message.id;
        _followOutput = false;
        _contentBelow = false;
      });
      if (!cleaned) _imageNotice('消息已更新，部分旧图片清理失败');
      await _continuePending();
    } on Object {
      if (!mounted || !identical(_editing, session)) return;
      _updateEditing(() => session.saving = false);
      _imageNotice('消息保存失败，请重试');
    }
  }
}
