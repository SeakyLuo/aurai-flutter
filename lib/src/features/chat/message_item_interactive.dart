part of 'message_item.dart';

extension MessageItemInteractive on _MessageItemState {
  bool get _isProgramCard =>
      message.interactive != null &&
      message.interactive!.participation['_programMessage'] != null;

  Widget _ownProgramCard(BuildContext context) => Material(
    key: _bubbleKey,
    color: GlobalUI.messageBackground(Theme.of(context)),
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onLocate,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _previewContent(_interactiveContent(context)),
      ),
    ),
  );

  Widget _interactiveContent(BuildContext context) {
    final page = InteractivePageScope.of(context);
    return IgnorePointer(
      ignoring: widget.readOnly && widget.onLocate != null,
      child: InteractiveMessageView(
        key: ValueKey(page?.sequence),
        messageId: message.id,
        card: page?.snapshot ?? message.interactive!,
        showQuestionRecipient: message.isGroupMessage,
        members: widget.interactiveMembers,
        onOpenMember: widget.onOpenMember,
        historical: page?.snapshot != null,
        readOnly: widget.readOnly || page?.snapshot != null,
        onClick: widget.onInteractiveClick!,
        onRetry: widget.onInteractiveRetry,
        onCancelVote: (revision, participantRevision) => ImageActionScope.of(
          context,
        ).cancelInteractiveVote(message.id, revision, participantRevision),
        onStatistics: !widget.readOnly || widget.onLocate != null
            ? () => showInteractiveStatistics(
                context,
                controller: ImageActionScope.of(context),
                database: ImageActionScope.of(context).groupStore.database,
                messageId: message.id,
              )
            : null,
        onOpenLink: (url) => _openLink(context, url),
      ),
    );
  }
}
