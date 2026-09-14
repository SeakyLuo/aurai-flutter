import 'group_message_heading.dart';
import 'task_failure_icon.dart';
import 'message_quote_view.dart';
import 'image_action_scope.dart';
import 'file_attachments.dart';
import 'reply_image_syntax.dart';
import 'reply_image_gallery.dart';
import 'markdown_link_underlines.dart';
import 'cjk_strong_syntax.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/global_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/agent_models.dart';
import '../../domain/source_reference.dart';
import '../../domain/web_sources.dart';
import '../../platform/aurai_platform.dart';
import 'image_attachments.dart';
import 'task_summary_view.dart';
import 'copy_icon.dart';
import 'message_actions_menu.dart';
import 'message_time.dart';
import 'source_citation_syntax.dart';
import 'source_citation_view.dart';

class MessageItem extends StatefulWidget {
  static const userTopMargin = 16.0;
  const MessageItem({
    super.key,
    required this.message,
    required this.onEdit,
    this.streaming = false,
    this.groupBubble = false,
    this.onQuote,
    this.onRecall,
    this.onOpenQuote,
    this.onOpenMember,
    this.availableSources = const {},
    this.excludedActivityMessageId,
  });
  final AgentMessage message;
  final ValueChanged<AgentMessage>? onQuote;
  final Future<void> Function(AgentMessage)? onRecall;
  final ValueChanged<String>? onOpenQuote;
  final ValueChanged<String>? onOpenMember;
  final String? excludedActivityMessageId;
  final bool streaming;
  final bool groupBubble;
  final Map<String, SourceReference> availableSources;
  final Future<void> Function(AgentMessage)? onEdit;

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  AgentMessage get message => widget.message;
  late Widget _content;
  List<SourceReference> _sources = const [];
  bool _copied = false;
  final _bubbleKey = GlobalKey();
  Timer? _copyResetTimer;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _content = _buildContent(context);
  }

  @override
  void didUpdateWidget(MessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != message ||
        oldWidget.groupBubble != widget.groupBubble ||
        !mapEquals(oldWidget.availableSources, widget.availableSources)) {
      _content = _buildContent(context);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ImageMessageScope(messageId: message.id, child: _buildMessage(context));

  Widget _buildMessage(BuildContext context) =>
      message.role == AgentMessageRole.user
      ? _withActions(_content)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.groupBubble && message.taskSummary != null)
              TaskSummaryView(
                excludedMessageId: widget.excludedActivityMessageId,
                messageId: message.id,
                summary: message.taskSummary!,
                onOpenLink: (href) => _openLink(context, href),
              ),
            if (widget.groupBubble || message.taskSummary?.stopped != true)
              _selectableContent(),
            if (!widget.groupBubble &&
                !widget.streaming &&
                message.taskSummary?.stopped != true)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 18, 20),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _copied ? '已复制' : '复制回复',
                      onPressed: () => _copy(context),
                      icon: CopyIcon(copied: _copied),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(32),
                        minimumSize: const Size.square(32),
                        padding: const EdgeInsets.all(4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (widget.onQuote != null)
                      IconButton(
                        tooltip: '引用',
                        onPressed: () => widget.onQuote!(message),
                        icon: const QuoteIcon(),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(32),
                          minimumSize: const Size.square(32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: messageTime(message.createdAt),
                      triggerMode: TooltipTriggerMode.tap,
                      child: Text(
                        messageTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_sources.isNotEmpty) ...[
                      const Spacer(),
                      MessageSourcesButton(
                        sources: _sources,
                        onOpenLink: (href) => _openLink(context, href),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );

  Widget _selectableContent() {
    if (widget.groupBubble) return _content;
    final content = SelectionArea(
      contextMenuBuilder: (context, selection) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selection.contextMenuAnchors,
            buttonItems: [
              ...selection.contextMenuButtonItems,
              if (widget.onQuote != null)
                ContextMenuButtonItem(
                  label: '引用',
                  onPressed: () {
                    selection.hideToolbar();
                    selection.clearSelection();
                    widget.onQuote!(message);
                  },
                ),
            ],
          ),
      child: _content,
    );
    return widget.onQuote == null ? content : _withActions(content);
  }

  Widget _withActions(Widget child) => GestureDetector(
    onLongPressStart: (details) => _openActions(details.globalPosition),
    child: child,
  );

  Future<void> _openActions(Offset position) async {
    final snapshot = message;
    final action = await showMessageActionsMenu(
      context,
      message: snapshot,
      position: position,
      allowEditing: widget.onEdit != null,
      allowQuote: widget.onQuote != null,
      allowRecall: widget.onRecall != null,
    );
    if (!mounted) return;
    switch (action) {
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

  Widget _buildContent(BuildContext context) {
    if (message.role == AgentMessageRole.user) {
      return LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: widget.groupBubble
                  ? constraints.maxWidth - GroupMessageHeading.contentInset
                  : (constraints.maxWidth - 32) * 0.82,
            ),
            margin: EdgeInsets.fromLTRB(
              widget.groupBubble ? 18 : 16,
              widget.groupBubble ? 0 : MessageItem.userTopMargin,
              widget.groupBubble ? 18 : 16,
              widget.groupBubble ? 0 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.quote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MessageQuoteView(
                      quote: message.quote!,
                      onTap: () =>
                          widget.onOpenQuote?.call(message.quote!.messageId),
                    ),
                  ),
                for (final file in message.files)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FileAttachmentCard(file: file),
                  ),
                if (message.images.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final image in message.images)
                        ImageAttachment(
                          image: image,
                          gallery: message.images,
                          size: message.images.length == 1
                              ? ((constraints.maxWidth - 32) * 0.72).clamp(
                                  80.0,
                                  260.0,
                                )
                              : ((constraints.maxWidth - 32) * 0.82 - 8) / 2,
                        ),
                    ],
                  ),
                if (message.images.isNotEmpty && message.text.isNotEmpty)
                  const SizedBox(height: 8),
                if (message.text.isNotEmpty)
                  Material(
                    key: _bubbleKey,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xff51406c)
                        : GlobalUI.userMessageBackground,
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onLongPress: () {
                        final box =
                            _bubbleKey.currentContext!.findRenderObject()!
                                as RenderBox;
                        _openActions(
                          box.localToGlobal(box.size.center(Offset.zero)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xffeee8f7)
                                : const Color(0xff352b43),
                            fontSize: widget.groupBubble ? 15 : 16,
                            height: widget.groupBubble ? 1.4 : 1.55,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final body = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: widget.groupBubble ? 15 : 16,
      height: widget.groupBubble ? 1.4 : 1.65,
    );
    final availableSources = {
      ...widget.availableSources,
      ...webSourcesFromActivities(message.taskSummary?.activities ?? const []),
    };
    _sources = messageSources(message.text, availableSources: availableSources);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.images.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: message.text.isEmpty ? 0 : 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in message.images)
                  ImageAttachment(
                    image: image,
                    gallery: message.images,
                    size: message.images.length == 1 ? 220 : 120,
                  ),
              ],
            ),
          ),
        if (message.quote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageQuoteView(
              quote: message.quote!,
              onTap: () => widget.onOpenQuote?.call(message.quote!.messageId),
            ),
          ),
        MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: MarkdownLinkUnderlines(
            child: MarkdownBody(
              blockSyntaxes: [ReplyImageSyntax()],
              inlineSyntaxes: [
                SourceCitationSyntax(availableSources),
                SourceLinkSyntax(availableSources),
                CjkStrongSyntax(),
              ],
              builders: {
                'reference-gallery': ReplyImageGalleryBuilder(
                  (url) => _openLink(context, url),
                ),
                'source-citation': SourceCitationBuilder(
                  onOpenLink: (href) => _openLink(context, href),
                ),
              },
              data: imageMarkdownForDisplay(message.text, widget.streaming),
              selectable: false,
              fitContent: widget.groupBubble,
              onTapLink: (text, href, title) => _openLink(context, href),
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          width: 0.5,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    p: body,
                    strong: const TextStyle(fontWeight: FontWeight.w700),
                    h1: body.copyWith(
                      fontSize: widget.groupBubble ? 22 : 25,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    h2: body.copyWith(
                      fontSize: widget.groupBubble ? 19 : 21,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    h3: body.copyWith(
                      fontSize: widget.groupBubble ? 17 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                    h1Padding: const EdgeInsets.only(top: 12),
                    h2Padding: const EdgeInsets.only(top: 12),
                    h3Padding: const EdgeInsets.only(top: 8),
                    blockSpacing: 20,
                    listIndent: 24,
                    listBullet: body,
                    blockquote: body,
                    blockquotePadding: const EdgeInsets.only(
                      left: 18,
                      top: 2,
                      bottom: 2,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 3,
                        ),
                      ),
                    ),
                    code: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: widget.groupBubble ? 13 : 14,
                      height: widget.groupBubble ? 1.4 : 1.6,
                      color: Theme.of(context).colorScheme.onSurface,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    codeblockPadding: const EdgeInsets.all(16),
                    tableColumnWidth: const IntrinsicColumnWidth(),
                    tableScrollbarThumbVisibility: true,
                    tablePadding: const EdgeInsets.only(bottom: 12),
                    tableBody: body.copyWith(
                      fontSize: widget.groupBubble ? 14 : 15,
                    ),
                    tableHead: body.copyWith(
                      fontSize: widget.groupBubble ? 14 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    tableCellsPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tableBorder: TableBorder.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    a: body.merge(GlobalUI.linkStyle(context)),
                  ),
            ),
          ),
        ),
      ],
    );
    if (!widget.groupBubble) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: content,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Material(
            key: _bubbleKey,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff2a292f)
                : const Color(0xffefeff3),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onLongPress: () {
                final box =
                    _bubbleKey.currentContext!.findRenderObject()! as RenderBox;
                _openActions(box.localToGlobal(box.size.center(Offset.zero)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: message.isFailure
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: TaskFailureIcon(size: 18),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(message.text, style: body)),
                        ],
                      )
                    : content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, [String? text]) async {
    try {
      await Clipboard.setData(ClipboardData(text: text ?? message.text));
      if (!mounted) return;
      _copyResetTimer?.cancel();
      setState(() => _copied = true);
      _copyResetTimer = Timer(const Duration(milliseconds: 1500), () {
        setState(() => _copied = false);
      });
    } on Object {
      if (context.mounted) _notice(context, '复制失败，请重试');
    }
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    final memberLink = Uri.tryParse(href ?? '');
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
        if (context.mounted) _notice(context, error.message ?? '无法打开此文件');
      } on Object {
        if (context.mounted) _notice(context, '无法打开此文件');
      }
      return;
    }
    final uri = Uri.tryParse(href ?? '');
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      _notice(context, '无法打开此链接');
      return;
    }
    try {
      await AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': uri.toString(),
      });
    } on Object {
      if (context.mounted) _notice(context, '无法打开链接，请稍后再试');
    }
  }

  void _notice(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
