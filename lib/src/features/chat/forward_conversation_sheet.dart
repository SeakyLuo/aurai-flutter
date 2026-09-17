import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/error_message.dart';
import 'chat_controller.dart';
import 'group_message_heading.dart';
import 'message_time.dart';
import 'recalled_message_notice.dart';
import 'html_message_preview.dart';
import 'message_item.dart';
import 'glass_surface.dart';
import 'chat_header_background.dart';

class ForwardConversationSheet extends StatefulWidget {
  const ForwardConversationSheet({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.title,
    required this.kind,
  });
  final ChatController controller;
  final String conversationId, title;
  final ConversationKind kind;

  @override
  State<ForwardConversationSheet> createState() =>
      _ForwardConversationSheetState();
}

class _ForwardConversationSheetState extends State<ForwardConversationSheet> {
  final _messages = <AgentMessage>[];
  final _scroll = ScrollController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _loading = false, _more = true;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    if (_scroll.position.extentAfter < 250) _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    try {
      final page = await widget.controller.previewConversationMessages(
        widget.conversationId,
        before: _messages.lastOrNull,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(page.reversed);
        _more = page.length == 50;
      });
    } on Object catch (error) {
      if (mounted)
        _messenger.currentState!.showSnackBar(
          SnackBar(
            content: Text('会话读取失败：${errorMessage(error)}'),
            action: SnackBarAction(label: '重试', onPressed: _load),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: double.infinity,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            primary: false,
            toolbarHeight: 76,
            titleSpacing: 18,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            forceMaterialTransparency: true,
            flexibleSpace: const ChatHeaderBackground(),
            title: Row(
              children: [
                GlassSurface(
                  radius: 28,
                  child: RoundAction(
                    icon: Icons.arrow_back_rounded,
                    label: '返回',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 50),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: _messages.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('暂无消息'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.only(top: 88, bottom: 16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length)
                        return const Center(child: CircularProgressIndicator());
                      final message = _messages[index];
                      final group = widget.kind == ConversationKind.group;
                      final older = index + 1 < _messages.length
                          ? _messages[index + 1]
                          : null;
                      final showTime =
                          older == null ||
                          message.createdAt
                                  .difference(older.createdAt)
                                  .inMinutes >=
                              5;
                      final content = MessageItem(
                        key: ValueKey(message.id),
                        message: message,
                        groupBubble: group,
                        readOnly: true,
                        onEdit: null,
                        onInteractiveClick: (_, _, _, {value}) async => null,
                        htmlGameView: message.htmlGame == null
                            ? null
                            : HtmlMessagePreview(
                                title: message.htmlGame!.title,
                                preview: message.htmlGame!.preview,
                              ),
                      );
                      return IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showTime)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  24,
                                  18,
                                  12,
                                ),
                                child: Text(
                                  messageTime(message.createdAt),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (message.isSystem)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                child: RecalledMessageNotice(
                                  message: message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.only(top: group ? 12 : 0),
                                child:
                                    group &&
                                        message.role ==
                                            AgentMessageRole.assistant &&
                                        message.sender != null
                                    ? GroupMessageHeading(
                                        sender: message.sender!,
                                        isFailure: message.isFailure,
                                        showName: message.htmlGame == null,
                                        onOpenProfile: () {},
                                        child: content,
                                      )
                                    : content,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    ),
  );
}
