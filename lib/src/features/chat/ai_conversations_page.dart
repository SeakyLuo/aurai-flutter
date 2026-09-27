import '../../app/glass_notice.dart';
import 'conversation_list_skeleton.dart';
import 'conversation_status_dot.dart';
import '../../domain/error_message.dart';
import 'conversation_preview_text.dart';
import 'message_time.dart';
import 'home_page.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../storage/home_conversations.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'chat_page.dart';
import 'conversation_icon.dart';
import 'conversation_more.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';
import 'message_composer.dart';
import 'glass_surface.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({
    super.key,
    required this.controller,
    required this.profile,
  });
  final ChatController controller;
  final AiProfile profile;
  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage>
    with RouteAware {
  final _items = <Conversation>[];
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false, _more = true, _failed = false;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    homeRouteObserver.subscribe(
      this,
      ModalRoute.of(context)! as PageRoute<dynamic>,
    );
  }

  @override
  void didPopNext() {
    _load(reset: true);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final page = await HomeConversations(
        widget.controller.groupStore,
      ).forAi(widget.profile.sender.id, offset: reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page);
        _more = page.length == HomeConversations.pageSize;
        _failed = false;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _failed = true);
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('会话加载失败：${errorMessage(error)}'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _load(reset: true),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open({String? id, String? message}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final target =
          id ??
          await widget.controller.openAiConversation(
            widget.profile,
            newConversation: true,
            freshDraft: message != null,
          );
      await widget.controller.selectConversation(target);
      if (!mounted) return;
      final route = MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          controller: widget.controller,
          stacked: true,
          initialText: message,
        ),
      );
      _focus.unfocus();
      if (message != null) _text.clear();
      await Navigator.push<void>(context, route);
      if (mounted) await _load(reset: true);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: widget.profile.sender.name,
      onBack: () => Navigator.pop(context),
      titleWidget: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AiContactPage(
              controller: widget.controller,
              senderId: widget.profile.sender.id,
            ),
          ),
        ),
        child: Text(widget.profile.sender.name),
      ),
    ),
    body: _items.isEmpty
        ? Center(
            child: _loading
                ? const ConversationListSkeleton()
                : _opening
                ? const CircularProgressIndicator()
                : _failed
                ? TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('重试加载'),
                  )
                : Text(
                    '还没有会话',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          )
        : PaginationListener(
            hasMore: _more,
            loadMore: _load,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                settingsHeaderHeight(context) + 8,
                16,
                24,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ConversationMore(
                  controller: widget.controller,
                  conversation: item,
                  onChanged: () => _load(reset: true),
                  child: Material(
                    color: item.isPinned
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.035)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListenableBuilder(
                      listenable: widget.controller.scheduledTasks,
                      builder: (context, _) => ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        leading: ConversationUnreadAvatar(
                          controller: widget.controller,
                          conversation: item,
                          child: const ConversationIcon(),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            if (item.lastMessageAt != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                conversationMessageTime(item.lastMessageAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: ConversationPreviewText(
                          showFailure: true,
                          conversation: item,
                          emptyText: '新会话',
                        ),
                        onTap: () => _open(id: item.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _text,
        builder: (context, value, _) => MessageComposer(
          controller: _text,
          focusNode: _focus,
          enabled: !_opening,
          hintText: '发消息，开始新会话',
          action: RoundAction(
            label: _opening ? '正在打开' : '发送',
            primary: true,
            compact: true,
            inkResponse: false,
            icon: Icons.arrow_upward_rounded,
            onPressed: !_opening && value.text.trim().isNotEmpty
                ? () => _open(message: value.text.trim())
                : null,
          ),
        ),
      ),
    ),
  );
}
