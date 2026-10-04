part of 'message_item.dart';

extension _FailureRetry on _MessageItemState {
  Future<void> _retryFailure() async {
    _setRetryingFailure(true);
    try {
      await widget.onRetry!(message);
    } finally {
      if (mounted) _setRetryingFailure(false);
    }
  }
}

extension _MessageItemActions on _MessageItemState {
  Future<void> _openBubbleMenu() => _bubbleTextSelection
      ? _selectionKey.currentState!.openMenu()
      : _openActions();

  Widget _selectableContent() {
    if (message.interactive != null) return _content;
    if (_hasBubble && message.htmlGame == null) {
      if (_bubbleTextSelection) {
        return GroupMessageSelection(
          key: _selectionKey,
          onChanged: (text) => _selectedText = text,
          onOpenMenu: () async {
            var acted = false;
            await _openActions(
              preserveSelection: true,
              onActionSelected: () => acted = true,
            );
            return acted;
          },
          onQuote: widget.onQuote == null
              ? null
              : (text) => widget.onQuote!(message, selectedText: text),
          onStar: !widget.readOnly || widget.onLocate != null
              ? () => _openActions(directAction: MessageAction.star)
              : null,
          onForward: () => _openActions(directAction: MessageAction.forward),
          onReadAloud: _canReadAloud
              ? (text) => _readAloud(message, text: text)
              : null,
          child: _content,
        );
      }
      return message.isReasoning ? _withActions(_content) : _content;
    }
    if (widget.streaming) return _withActions(_content);
    if (message.htmlGame != null) {
      return widget.onQuote == null && widget.onQuickReply == null
          ? _content
          : _withActions(_content);
    }
    final content = SelectionArea(
      onSelectionChanged: (selection) => _selectedText = selection?.plainText,
      contextMenuBuilder: (context, selection) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selection.contextMenuAnchors,
            buttonItems: [
              ...selection.contextMenuButtonItems,
              if (widget.onQuote != null)
                ContextMenuButtonItem(
                  label: '引用',
                  onPressed: () {
                    final text = _selectedText;
                    selection.hideToolbar();
                    selection.clearSelection();
                    widget.onQuote!(message, selectedText: text);
                  },
                ),
            ],
          ),
      child: _content,
    );
    return content;
  }

  bool get _hasBubble =>
      widget.groupBubble ||
      message.role == AgentMessageRole.user ||
      message.interactive != null ||
      message.htmlGame != null ||
      message.miniappShare != null;

  bool get _bubbleTextSelection =>
      _hasBubble &&
      !widget.streaming &&
      !message.isReasoning &&
      !message.isFailure &&
      !message.isSystem &&
      message.htmlGame == null &&
      message.interactive == null &&
      message.miniappShare == null &&
      message.text.isNotEmpty;

  bool get _canReadAloud =>
      !widget.streaming &&
      message.role == AgentMessageRole.assistant &&
      !message.isSystem &&
      !message.isReasoning &&
      !message.isFailure &&
      message.htmlGame == null &&
      message.text.isNotEmpty;

  Future<void> _readAloud(AgentMessage snapshot, {String? text}) async {
    await runUiAction(
      context,
      () => toggleSpeechReadout(
        context,
        key: snapshot.id,
        controller: ImageActionScope.of(context),
        senderId: snapshot.senderId,
        text: _copyableText(text ?? snapshot.text),
      ),
    );
  }

  Future<void> _openActions({
    MessageAction? directAction,
    bool compactMenu = false,
    bool preserveSelection = false,
    VoidCallback? onActionSelected,
  }) async {
    final snapshot = message;
    var hasHistory = false;
    var allowRetry = widget.onRetry != null && snapshot.isFailure;
    final database = ImageActionScope.of(context).groupStore.database;
    if (widget.onRetry != null && !snapshot.isFailure) {
      try {
        final runs = await database.query(
          'agent_runs',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [snapshot.runId],
        );
        allowRetry = runs.isNotEmpty && runs.single['status'] == 'failed';
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text(errorMessage(error))),
            kind: ToastKind.error,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    final allowStar =
        !widget.streaming &&
        !snapshot.isSystem &&
        !snapshot.isReasoning &&
        (!widget.readOnly || widget.onLocate != null);
    var starred = false;
    MiniappEntry? miniapp;
    if (allowStar) {
      try {
        if (snapshot.htmlGame?.appId case final appId?) {
          miniapp = await MiniappLibraryStore(database).entryForApp(appId);
          starred = await MiniappFavorites(database).contains(miniapp);
        } else {
          starred = await StarredMessages(database).contains(snapshot.id);
        }
      } on Object catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text(errorMessage(error))),
            kind: ToastKind.error,
          );
        return;
      }
      if (!mounted) return;
    }
    if (snapshot.interactive != null &&
        (!widget.readOnly || widget.onLocate != null)) {
      try {
        hasHistory = await hasInteractiveHistory(
          database,
          snapshot.id,
          MessageSender.localUser.id,
        );
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text(errorMessage(error))),
            kind: ToastKind.error,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    GroupMessageMarkStatus? groupMark;
    if (allowStar) {
      final loaded = await runUiAction(context, () async {
        groupMark = await GroupMessageMarks(
          ImageActionScope.of(context).groupStore,
        ).status(snapshot.id);
      });
      if (!loaded || !mounted) return;
    }
    var allowVisibility = false;
    if (widget.groupBubble) {
      final loaded = await runUiAction(context, () async {
        final groups = await database.query(
          'conversations',
          columns: ['id'],
          where:
              'kind = ? AND id = (SELECT conversation_id FROM messages WHERE id = ?)',
          whereArgs: ['group', snapshot.id],
        );
        allowVisibility = groups.isNotEmpty;
      });
      if (!loaded || !mounted) return;
    }
    final result = directAction != null
        ? MessageActionResult(directAction)
        : await showMessageActionsMenu(
            context,
            message: snapshot,
            groupMenu: true,
            preserveSelection: preserveSelection,
            allowReadAloud: _canReadAloud,
            onVisibility: allowVisibility
                ? (sheetContext) async {
                    await runUiAction(
                      sheetContext,
                      () => showMessageVisibilitySheet(
                        sheetContext,
                        message: snapshot,
                        database: database,
                      ),
                    );
                  }
                : null,
            allowStar: allowStar,
            allowGroupMarks: groupMark != null,
            pinned: groupMark?.pinned ?? false,
            groupFavorite: groupMark?.favorite ?? false,
            allowCopy: true,
            allowSelect: !compactMenu && !_hasBubble,
            starred: starred,
            allowEditing:
                widget.onEdit != null && snapshot.miniappShare == null,
            allowHistory: hasHistory,
            allowQuote: widget.onQuote != null,
            allowRecall: widget.onRecall != null,
            allowRetry: allowRetry,
            allowForward:
                !widget.streaming &&
                (message.htmlGame != null ||
                    message.text.isNotEmpty ||
                    message.images.isNotEmpty ||
                    message.files.isNotEmpty),
            allowBranch: compactMenu && widget.onBranch != null,
            allowQuickReply:
                widget.onQuickReply != null &&
                (!widget.streaming ||
                    snapshot.senderId == MessageSender.localUser.id) &&
                !snapshot.isSystem &&
                !snapshot.isReasoning &&
                (snapshot.role == AgentMessageRole.assistant ||
                    snapshot.senderId == MessageSender.localUser.id),
            sentQuickReplyKeys:
                !widget.groupBubble &&
                    snapshot.role == AgentMessageRole.assistant
                ? const {}
                : snapshot.quickReplies
                      .where(
                        (reply) => reply.senderId == MessageSender.localUser.id,
                      )
                      .map((reply) => reply.key)
                      .toSet(),
          );
    if (!mounted || result == null) return;
    onActionSelected?.call();
    if (result is MessageMenuDismissResult) return;
    if (result case MessageQuickReplyResult(:final option)) {
      await widget.onQuickReply?.call(snapshot, option.key);
      return;
    }
    final action = (result as MessageActionResult).action;
    switch (action) {
      case MessageAction.pin:
      case MessageAction.groupFavorite:
        final mark = groupMark!;
        await runUiAction(context, () async {
          final store = GroupMessageMarks(
            ImageActionScope.of(context).groupStore,
          );
          if (action == MessageAction.pin) {
            await store.pin(mark.groupId, snapshot.id, !mark.pinned);
          } else {
            await store.favorite(mark.groupId, snapshot.id, !mark.favorite);
          }
        });
      case MessageAction.retry:
        await widget.onRetry?.call(snapshot);
      case MessageAction.star:
        try {
          if (miniapp != null) {
            final favorites = MiniappFavorites(
              ImageActionScope.of(context).groupStore.database,
            );
            if (starred) {
              await favorites.remove(miniapp);
            } else {
              await favorites.add(miniapp);
            }
            if (mounted)
              ScaffoldMessenger.of(context).showToast(
                SnackBar(content: Text(starred ? '已取消收藏' : '已收藏小程序')),
                kind: ToastKind.success,
              );
            return;
          }
          final store = StarredMessages(
            ImageActionScope.of(context).groupStore.database,
          );
          if (starred) {
            await removeFavorite(context, store, snapshot.id);
          } else {
            await store.set(snapshot.id, true);
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showToast(const SnackBar(content: Text('已收藏')));
          }
        } on Object catch (error) {
          if (mounted)
            ScaffoldMessenger.of(context).showToast(
              SnackBar(content: Text(errorMessage(error))),
              kind: ToastKind.error,
            );
        }
      case MessageAction.readAloud:
        await _readAloud(
          snapshot,
          text: preserveSelection ? _selectedText : null,
        );
      case MessageAction.history:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => InteractiveHistoryPage(
              database: ImageActionScope.of(context).groupStore.database,
              messageId: snapshot.id,
            ),
          ),
        );
      case MessageAction.fullscreen:
        await (widget.htmlView! as HtmlView).openFullscreen(context);
      case MessageAction.forward:
        final htmlCard = snapshot.htmlGame;
        if (htmlCard != null) {
          try {
            final controller = ImageActionScope.of(context);
            final entry = await MiniappLibraryStore(
              controller.groupStore.database,
            ).entryForMessage(snapshot.id);
            if (mounted) await forwardMiniapp(context, entry);
          } on Object catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showToast(
                SnackBar(content: Text(errorMessage(error))),
                kind: ToastKind.error,
              );
            }
            return;
          }
          return;
        }
        late String targetConversationId;
        final controller = ImageActionScope.of(context);
        final sent = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ImageForwardPage.message(
              controller: controller,
              onSent: (target) => targetConversationId = target.id,
              message: AgentMessage(
                id: snapshot.id,
                senderId: snapshot.senderId,
                role: snapshot.role,
                text: snapshot.text,
                images: List.of(snapshot.images),
                files: List.of(snapshot.files),
                htmlGame: htmlCard,
                miniappShare: snapshot.miniappShare,
                interactive: snapshot.interactive,
                createdAt: snapshot.createdAt,
              ),
            ),
          ),
        );
        if (mounted && sent == true) {
          if (snapshot.miniappShare != null) {
            showMiniappShareNotice(
              context,
              controller,
              targetConversationId,
              text: '已转发',
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showToast(const SnackBar(content: Text('已转发')));
          }
        }
      case MessageAction.branch:
        await widget.onBranch?.call(snapshot);
      case MessageAction.recall:
        await widget.onRecall?.call(snapshot);
      case MessageAction.quote:
        widget.onQuote?.call(
          snapshot,
          selectedText: preserveSelection ? _selectedText : null,
        );
      case MessageAction.copy:
        await _copy(
          context,
          _copyableText(
            preserveSelection
                ? (_selectedText ?? snapshot.text)
                : snapshot.text,
          ),
        );
      case MessageAction.select:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                MessageTextSelectionPage(text: _copyableText(snapshot.text)),
          ),
        );
      case MessageAction.edit:
        await widget.onEdit?.call(snapshot);
    }
  }

  Widget _buildQuickReplies(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(widget.groupBubble ? 0 : 18, 8, 18, 0),
    child: QuickReplyChips(
      replies: message.quickReplies,
      database: ImageActionScope.of(context).groupStore.database,
      onTap: widget.onQuickReply == null
          ? null
          : (key) => widget.onQuickReply!(message, key),
    ),
  );
}
