part of 'message_item.dart';

extension _MessageItemActions on _MessageItemState {
  Future<void> _openActions() async {
    final snapshot = message;
    var hasHistory = false;
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
          ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
        }
        return;
      }
      if (!mounted) return;
    }
    final action = await showMessageActionsMenu(
      context,
      message: snapshot,
      allowEditing: widget.onEdit != null,
      allowStatistics:
          snapshot.interactive
                  ?.viewFor(MessageSender.localUser.id)
                  .showStatistics ==
              true &&
          (!widget.readOnly || widget.onLocate != null),
      allowHistory: hasHistory,
      allowQuote: widget.onQuote != null,
      allowRecall: widget.onRecall != null,
      allowForward:
          !widget.streaming &&
          (message.htmlGame != null ||
              message.text.isNotEmpty ||
              message.images.isNotEmpty ||
              message.files.isNotEmpty),
      allowQuickReply:
          widget.onQuickReply != null &&
          !widget.streaming &&
          !snapshot.isSystem &&
          !snapshot.isFailure &&
          !snapshot.isReasoning &&
          snapshot.role == AgentMessageRole.assistant,
      sentQuickReplyKey: snapshot.quickReplies
          .where((reply) => reply.senderId == MessageSender.localUser.id)
          .firstOrNull
          ?.key,
    );
    if (!mounted) return;
    switch (action) {
      case MessageAction.quickDislike:
      case MessageAction.quickLove:
      case MessageAction.quickLaugh:
      case MessageAction.quickCelebrate:
      case MessageAction.quickSmile:
      case MessageAction.quickSurprised:
      case MessageAction.quickSad:
      case MessageAction.quickAngry:
      case MessageAction.quickThinking:
      case MessageAction.quickSweat:
      case MessageAction.quickSpeechless:
      case MessageAction.quickCool:
      case MessageAction.quickClap:
      case MessageAction.quickThanks:
      case MessageAction.quickStrong:
      case MessageAction.quickFire:
      case MessageAction.quickHundred:
      case MessageAction.quickHug:
      case MessageAction.quickHeartEyes:
      case MessageAction.quickRainbow:
      case MessageAction.quickFlower:
      case MessageAction.quickGift:
      case MessageAction.quickRocket:
      case MessageAction.quickCoffee:
      case MessageAction.quickDiamond:
      case MessageAction.quickClover:
      case MessageAction.quickIce:
      case MessageAction.quickParty:
      case MessageAction.quickBullseye:
      case MessageAction.quickPenguin:
      case MessageAction.quickCat:
      case MessageAction.quickUnicorn:
      case MessageAction.quickGhost:
      case MessageAction.quickRobot:
      case MessageAction.quickPoop:
      case MessageAction.quickMelon:
      case MessageAction.quickLemon:
      case MessageAction.quickBeer:
      case MessageAction.quickBrokenHeart:
      case MessageAction.quickWiltedFlower:
      case MessageAction.quickSleep:
      case MessageAction.quickDog:
      case MessageAction.quickLike:
      case MessageAction.quickPlusOne:
      case MessageAction.quickDone:
      case MessageAction.quickReceived:
      case MessageAction.quickViewing:
      case MessageAction.quickQuestion:
        final reply = quickReplyForAction(action!);
        await widget.onQuickReply?.call(snapshot, reply!.key, reply.text);
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
              ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
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
          ).showSnackBar(const SnackBar(content: Text('已转发')));
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
      case null:
        break;
    }
  }

  Widget _buildQuickReplies(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(widget.groupBubble ? 0 : 18, 8, 18, 0),
    child: QuickReplyChips(
      replies: message.quickReplies,
      database: ImageActionScope.of(context).groupStore.database,
      onTap: widget.onQuickReply == null
          ? null
          : (key, text) => widget.onQuickReply!(message, key, text),
    ),
  );
}
