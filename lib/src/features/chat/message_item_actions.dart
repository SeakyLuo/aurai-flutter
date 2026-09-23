part of 'message_item.dart';

extension _MessageItemActions on _MessageItemState {
  Future<void> _openActions({bool compactMenu = false}) async {
    final snapshot = message;
    var hasHistory = false;
    final allowStar =
        !widget.streaming &&
        !snapshot.isSystem &&
        !snapshot.isReasoning &&
        (!widget.readOnly || widget.onLocate != null);
    var starred = false;
    MiniappEntry? miniapp;
    if (allowStar) {
      try {
        final database = ImageActionScope.of(context).groupStore.database;
        if (snapshot.htmlGame?.appId case final appId?) {
          miniapp = await MiniappLibraryStore(database).entryForApp(appId);
          starred = await MiniappFavorites(database).contains(miniapp);
        } else {
          starred = await StarredMessages(database).contains(snapshot.id);
        }
      } on Object catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
        return;
      }
      if (!mounted) return;
    }
    if (snapshot.interactive != null &&
        (!widget.readOnly || widget.onLocate != null)) {
      try {
        hasHistory = await hasInteractiveHistory(
          ImageActionScope.of(context).groupStore.database,
          snapshot.id,
          MessageSender.localUser.id,
        );
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
        }
        return;
      }
      if (!mounted) return;
    }
    final result = await showMessageActionsMenu(
      context,
      message: snapshot,
      allowStar: allowStar,
      allowCopy: !compactMenu,
      allowSelect: !compactMenu,
      starred: starred,
      allowEditing: widget.onEdit != null,
      allowStatistics:
          snapshot.interactive
                  ?.viewFor(MessageSender.localUser.id)
                  .showStatistics ==
              true &&
          (!widget.readOnly || widget.onLocate != null),
      allowHistory: hasHistory,
      allowQuote: !compactMenu && widget.onQuote != null,
      allowRecall: widget.onRecall != null,
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
          !widget.groupBubble && snapshot.role == AgentMessageRole.assistant
          ? const {}
          : snapshot.quickReplies
                .where((reply) => reply.senderId == MessageSender.localUser.id)
                .map((reply) => reply.key)
                .toSet(),
    );
    if (!mounted || result == null) return;
    if (result case MessageQuickReplyResult(:final option)) {
      await widget.onQuickReply?.call(snapshot, option.key);
      return;
    }
    final action = (result as MessageActionResult).action;
    switch (action) {
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
              ScaffoldMessenger.of(context).showGlassSnackBar(
                SnackBar(content: Text(starred ? '已取消收藏' : '已收藏小程序')),
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
              ).showGlassSnackBar(const SnackBar(content: Text('已收藏')));
          }
        } on Object catch (error) {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
        }
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
      case MessageAction.statistics:
        await showInteractiveStatistics(
          context,
          database: ImageActionScope.of(context).groupStore.database,
          messageId: snapshot.id,
        );
      case MessageAction.fullscreen:
        await (widget.htmlGameView! as HtmlGameView).openFullscreen(context);
      case MessageAction.forward:
        var htmlCard = snapshot.htmlGame;
        if (htmlCard != null) {
          try {
            htmlCard = await (widget.htmlGameView! as HtmlGameView)
                .captureForwardPreview();
          } on Object catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
            }
            return;
          }
          if (!mounted) return;
        }
        final sent = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ImageForwardPage.message(
              controller: ImageActionScope.of(context),
              message: AgentMessage(
                id: snapshot.id,
                senderId: snapshot.senderId,
                role: snapshot.role,
                text: snapshot.text,
                images: List.of(snapshot.images),
                files: List.of(snapshot.files),
                htmlGame: htmlCard,
                interactive: snapshot.interactive,
                createdAt: snapshot.createdAt,
              ),
            ),
          ),
        );
        if (mounted && sent == true) {
          ScaffoldMessenger.of(
            context,
          ).showGlassSnackBar(const SnackBar(content: Text('已转发')));
        }
      case MessageAction.recall:
        await widget.onRecall?.call(snapshot);
      case MessageAction.quote:
        widget.onQuote?.call(snapshot);
      case MessageAction.copy:
        await _copy(context, snapshot.text);
      case MessageAction.select:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MessageTextSelectionPage(text: snapshot.text),
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
