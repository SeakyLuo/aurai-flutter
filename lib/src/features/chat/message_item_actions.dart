part of 'message_item.dart';

extension _FailureRetry on _MessageItemState {
  Widget _failureCard() {
    final controller = ImageActionScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        controller.groupActivityChanges,
      ]),
      builder: (context, _) => FutureBuilder<Map<String, bool?>>(
        future: controller.failedRecoveryOptions(),
        // A recycled card must not briefly replace its resolved playback icon.
        initialData: controller.resolvedFailedRecoveryOptions,
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: MenuPressHighlight(
            onLongPressStart: (_) => _openBubbleMenu(),
            borderRadius: BorderRadius.circular(24),
            child: TaskFailureCard(
              error: message.text,
              padding: EdgeInsets.zero,
              actionLabel: snapshot.data?[message.id] == true ? '继续' : '重试',
              continuing: snapshot.data?[message.id] == true,
              enabled:
                  (snapshot.hasError || snapshot.data?[message.id] != null) &&
                  widget.onRetry != null &&
                  controller.canOfferFailedRetry(message),
              busy: _retryingFailure,
              onRetry: widget.onRetry == null ? null : _retryFailure,
            ),
          ),
        ),
      ),
    );
  }

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
  void _quote({String? selectedText}) {
    final heading = context
        .findAncestorWidgetOfExactType<GroupMessageHeading>();
    RenderBox sourceBox() {
      RenderBox? row;
      if (heading != null) {
        context.visitAncestorElements((element) {
          if (element.widget is GroupMessageHeading) {
            row = element.findRenderObject()! as RenderBox;
            return false;
          }
          return true;
        });
      }
      return row ??
          _quoteSourceKey.currentContext!.findRenderObject()! as RenderBox;
    }

    final source = sourceBox();
    widget.onQuote!(
      message,
      selectedText: selectedText,
      visual: QuoteFocusVisual(
        createdAt: message.createdAt,
        rect: source.localToGlobal(Offset.zero) & source.size,
        sourceRect: () {
          final current = sourceBox();
          return current.localToGlobal(Offset.zero) & current.size;
        },
        builder: (maxHeight) {
          final preview = MessageItem(
            message: message,
            onEdit: null,
            readOnly: true,
            previewMaxHeight: heading == null
                ? maxHeight
                : (maxHeight - 24).clamp(24.0, double.infinity),
            showSenderAvatar: widget.showSenderAvatar,
            groupBubble: widget.groupBubble,
            replyPart: widget.replyPart,
            htmlView: widget.htmlView,
            onInteractiveClick: widget.onInteractiveClick,
            mentionMembers: widget.mentionMembers,
            interactiveMembers: widget.interactiveMembers,
            availableSources: widget.availableSources,
          );
          return heading == null
              ? preview
              : IgnorePointer(
                  child: GroupMessageHeading(
                    sender: heading.sender,
                    showName: heading.showName,
                    showAvatar: heading.showAvatar,
                    groupId: heading.groupId,
                    trailingInset: heading.trailingInset,
                    onOpenProfile: heading.onOpenProfile,
                    child: preview,
                  ),
                );
        },
      ),
    );
  }

  Widget _previewContent(Widget child) => widget.previewMaxHeight == null
      ? child
      : ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.previewMaxHeight! - 24),
          child: SingleChildScrollView(child: IgnorePointer(child: child)),
        );

  Future<void> _openLink(BuildContext context, String? href) async {
    final memberLink = Uri.tryParse(href ?? '');
    if (memberLink?.scheme == 'aurai' && memberLink?.host == 'miniapp') {
      await openMiniappLink(context, memberLink!);
      return;
    }
    if (memberLink?.scheme == 'aurai' &&
        memberLink?.host == 'member' &&
        memberLink!.pathSegments.length == 1) {
      widget.onOpenMember?.call(memberLink.pathSegments.single);
      return;
    }
    final file = href == null
        ? null
        : SourceReference.fromLocalLink(href, '本地文件');
    if (file != null) {
      try {
        await AuraiPlatform.instance.openSourceFile(file.url);
      } on PlatformException catch (error) {
        if (context.mounted)
          _notice(
            context,
            error.message ?? '无法打开此文件：${errorMessage(error)}',
            kind: ToastKind.error,
          );
      } on Object catch (error) {
        if (context.mounted)
          _notice(
            context,
            '无法打开此文件：${errorMessage(error)}',
            kind: ToastKind.error,
          );
      }
      return;
    }
    final uri = Uri.tryParse(href ?? '');
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      _notice(context, '无法打开此链接', kind: ToastKind.error);
      return;
    }
    try {
      await AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': uri.toString(),
      });
    } on Object catch (error) {
      if (context.mounted)
        _notice(
          context,
          '无法打开链接，请稍后再试：${errorMessage(error)}',
          kind: ToastKind.error,
        );
    }
  }

  void _notice(
    BuildContext context,
    String text, {
    ToastKind kind = ToastKind.info,
  }) => ScaffoldMessenger.of(
    context,
  ).showToast(SnackBar(content: Text(text)), kind: kind);

  double get _ownMessageLeftInset => widget.groupBubble
      ? message.hasRestrictedAudience
            ? GroupMessageHeading.restrictedRightInset
            : GroupMessageHeading.rightInset
      : 16;

  Widget _withBubbleStatus(Widget child) => _withGroupFavorite(
    widget.groupBubble && message.hasRestrictedAudience
        ? MessageVisibilityMarker(
            isOwnMessage: message.role == AgentMessageRole.user,
            label: message.visibilityLabel,
            onPressed: () => runUiAction(
              context,
              () => showMessageVisibilitySheet(
                context,
                message: message,
                database: ImageActionScope.of(context).groupStore.database,
              ),
            ),
            child: child,
          )
        : child,
  );

  Future<void> _openBubbleMenu() => _bubbleTextSelection
      ? _selectionKey.currentState!.openMenu()
      : _openActions();

  Widget _selectableContent() {
    if (widget.previewMaxHeight != null) return _content;
    if (message.messageMetadata?.participation['_taskCard'] != null) {
      return _content;
    }
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
              : (text) => _quote(selectedText: text),
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
                    _quote(selectedText: text);
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
      message.messageMetadata?.participation['_taskCard'] == null &&
      message.text.isNotEmpty;

  bool get _canReadAloud =>
      !widget.streaming &&
      message.role == AgentMessageRole.assistant &&
      !message.isSystem &&
      !message.isReasoning &&
      !message.isFailure &&
      message.htmlGame == null &&
      message.interactive == null &&
      message.miniappShare == null &&
      message.messageMetadata?.participation['_taskCard'] == null &&
      message.images.isEmpty &&
      message.files.isEmpty &&
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
    var retryLabel =
        classifyModelFailure(
          ImageActionScope.of(context).activeConversation.errorDetail ?? '',
        ).canContinue
        ? '继续'
        : '重试';
    if (allowRetry) {
      final controller = ImageActionScope.of(context);
      final options = await controller.failedRecoveryOptions();
      if (!mounted) return;
      retryLabel = options[snapshot.id] == true ? '继续' : '重试';
      allowRetry =
          options[snapshot.id] != null &&
          controller.canOfferFailedRetry(snapshot);
    }
    final database = ImageActionScope.of(context).groupStore.database;
    var hasProcess = false;
    if (widget.groupBubble &&
        snapshot.runId != null &&
        snapshot.role == AgentMessageRole.assistant &&
        !snapshot.isSystem) {
      final loaded = await runUiAction(context, () async {
        hasProcess = await RunTimelineStore(
          database,
        ).hasProcess(snapshot.runId!);
      });
      if (!loaded || !mounted) return;
    }
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
    if (snapshot.interactive?.showHistory == true &&
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
    if (!widget.streaming &&
        !snapshot.isSystem &&
        (!widget.readOnly || widget.onLocate != null)) {
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
            allowGroupMarks: groupMark?.isGroup ?? false,
            allowMarks: groupMark != null,
            allowPin: groupMark?.canPin ?? false,
            pinned: groupMark?.pinned ?? false,
            groupFavorite: groupMark?.favorite ?? false,
            allowCopy: true,
            allowSelect: !compactMenu && !_hasBubble,
            starred: starred,
            allowEditing:
                widget.onEdit != null && snapshot.miniappShare == null,
            allowHistory: hasHistory,
            allowTimeline: hasProcess,
            allowQuote: widget.onQuote != null,
            allowRecall: widget.onRecall != null,
            allowRetry: allowRetry,
            retryLabel: retryLabel,
            allowForward:
                !widget.streaming &&
                (message.htmlGame != null ||
                    message.text.isNotEmpty ||
                    message.images.isNotEmpty ||
                    message.files.isNotEmpty),
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
      case MessageAction.timeline:
        await showRunTimelineSheet(
          context,
          controller: ImageActionScope.of(context),
          message: snapshot,
        );
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
            if (mounted) {
              ScaffoldMessenger.of(context).showToast(
                SnackBar(content: Text(mark.favorite ? '已取消标记' : '已标记')),
                kind: ToastKind.success,
              );
            }
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
              ScaffoldMessenger.of(context).showToast(
                const SnackBar(content: Text('已收藏')),
                kind: ToastKind.success,
              );
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
      case MessageAction.splitRun:
        await (widget.htmlView! as HtmlView).openSplit(context);
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
            ScaffoldMessenger.of(context).showToast(
              const SnackBar(content: Text('已转发')),
              kind: ToastKind.success,
            );
          }
        }
      case MessageAction.recall:
        await widget.onRecall?.call(snapshot);
      case MessageAction.quote:
        _quote(selectedText: preserveSelection ? _selectedText : null);
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
