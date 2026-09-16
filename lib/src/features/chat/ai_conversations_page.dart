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
import 'settings_icon.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({
    super.key,
    required this.controller,
    required this.profile,
    this.openEmptyConversation = true,
  });
  final ChatController controller;
  final AiProfile profile;
  final bool openEmptyConversation;
  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage>
    with RouteAware {
  final _items = <Conversation>[];
  bool _loading = false, _more = true, _failed = false;
  bool _firstLoad = true, _opening = false;
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
      final openEmpty =
          widget.openEmptyConversation &&
          _firstLoad &&
          _items.isEmpty &&
          ModalRoute.of(context)!.isCurrent;
      _firstLoad = false;
      if (openEmpty) await _open(null, true);
    } on Object catch (error) {
      if (mounted) setState(() => _failed = true);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _open([String? id, bool replace = false]) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final target =
          id ??
          await widget.controller.openAiConversation(
            widget.profile,
            newConversation: true,
          );
      await widget.controller.selectConversation(target);
      if (!mounted) return;
      final route = MaterialPageRoute<void>(
        builder: (_) => ChatPage(controller: widget.controller, stacked: true),
      );
      if (replace) {
        Navigator.of(context).pushReplacement<void, void>(route);
        return;
      }
      await Navigator.push<void>(context, route);
      if (mounted) await _load(reset: true);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
      actions: [
        SettingsGlassAction(
          label: '新建会话',
          icon: Icons.add_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.add),
          onPressed: _loading || _opening ? null : _open,
        ),
      ],
    ),
    body: _items.isEmpty
        ? Center(
            child: _loading || _opening
                ? const CircularProgressIndicator()
                : _failed
                ? TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('重试加载'),
                  )
                : TextButton.icon(
                    onPressed: _loading || _opening ? null : _open,
                    icon: const ConversationIcon(),
                    label: const Text('开始新会话'),
                  ),
          )
        : PaginationListener(
            hasMore: _more,
            loadMore: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                          vertical: 5,
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
                        onTap: () => _open(item.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
