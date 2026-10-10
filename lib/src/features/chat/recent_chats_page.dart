import '../../widgets/empty_data_view.dart';
import '../../domain/ai_profile.dart';
import 'animated_entry_list.dart';
import '../../app/glass_notice.dart';
import 'conversation_list_skeleton.dart';
import '../../scheduling/tasks_page.dart';
import 'settings_icon.dart';
import 'conversation_search_page.dart';
import 'conversation_list_tile.dart';
import '../../domain/error_message.dart';
import 'ai_contacts_page.dart';
import 'ai_contact_editor.dart';
import 'ai_contact_page.dart';
import 'header_action_menu.dart';
import 'file_tool_icon.dart';
import 'glass_surface.dart';
import 'projects_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import '../../storage/development_projects.dart';
import 'conversation_more.dart';
import 'chat_controller.dart';
import 'group_create_page.dart';
import 'group_avatar.dart';
import 'home_navigation.dart';
import 'pagination_listener.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

typedef _ReadCheckpoint = ({
  int groupReadAt,
  String groupReadId,
  int unreadMessageCount,
  String? activeRunId,
  String? seenRunId,
});

class RecentChatsPage extends StatefulWidget {
  const RecentChatsPage({
    super.key,
    required this.controller,
    this.groupsOnly = false,
    this.tasksOnly = false,
    this.profile,
  });
  final ChatController controller;
  final bool groupsOnly;
  final bool tasksOnly;
  final AiProfile? profile;
  @override
  State<RecentChatsPage> createState() => RecentChatsPageState();
}

class RecentChatsPageState extends State<RecentChatsPage> {
  bool get _tasks => widget.tasksOnly || widget.profile != null;
  bool get _root => !widget.groupsOnly && !_tasks;
  final _items = <Conversation>[];
  List<Conversation> _drafts = [];
  List<Conversation> get _visibleItems {
    if (_drafts.isEmpty) return _items;
    final storedIds = _items.map((item) => item.id).toSet();
    DateTime listTime(Conversation item) {
      final latest = item.lastMessageAt ?? item.createdAt;
      final edited = item.draftUpdatedAt;
      return edited != null && edited.isAfter(latest) ? edited : latest;
    }

    // Drafts are merged only for display; database pagination keeps its own
    // offset so a virtual entry cannot skip or repeat a stored conversation.
    return [
      ..._items,
      ..._drafts.where((draft) => !storedIds.contains(draft.id)),
    ]..sort((a, b) {
      final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinned != 0) return pinned;
      final time = listTime(b).compareTo(listTime(a));
      return time != 0 ? time : b.id.compareTo(a.id);
    });
  }

  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  final _projects = <String, DevelopmentProject>{};
  Timer? _updates;
  late final StreamSubscription<Conversation> _reads;
  final _readCheckpoints = <String, _ReadCheckpoint>{};
  int _groupCount = 0;
  bool _loading = false, _more = true, _loaded = false;
  bool _loadingMore = false;
  bool _reloadPending = false;
  @override
  void initState() {
    super.initState();
    reload();
    widget.controller.addListener(_changed);
    _reads = widget.controller.conversationReads.stream.listen(_readChanged);
  }

  void _readChanged(Conversation conversation) {
    final item = _items.where((item) => item.id == conversation.id).firstOrNull;
    if (item == null) return;
    final read = (
      groupReadAt: conversation.groupReadAt,
      groupReadId: conversation.groupReadId,
      unreadMessageCount: conversation.unreadMessageCount,
      activeRunId: conversation.activeRunId,
      seenRunId: conversation.seenRunId,
    );
    _readCheckpoints[conversation.id] = read;
    setState(() => _copyReadState(item, read));
  }

  void _copyReadState(Conversation item, _ReadCheckpoint read) {
    if (item.isTask) {
      if (item.activeRunId == read.activeRunId) {
        item.seenRunId = read.seenRunId;
      }
      return;
    }
    item.groupReadAt = read.groupReadAt;
    item.groupReadId = read.groupReadId;
    item.unreadMessageCount = read.unreadMessageCount;
  }

  void _changed() {
    if (!ModalRoute.of(context)!.isCurrent) return;
    if (_updates?.isActive == true) return;
    _updates = Timer(const Duration(milliseconds: 500), reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context);
    if (_loaded && current == true) _changed();
  }

  @override
  void dispose() {
    _updates?.cancel();
    _reads.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> reload() => _load(reset: true);
  Future<void> _load({bool reset = false}) async {
    final limit = reset && _items.length > HomeConversations.pageSize
        ? _items.length
        : HomeConversations.pageSize;
    if (_loading) {
      if (reset) _reloadPending = true;
      return;
    }
    setState(() {
      _loading = true;
      _loadingMore = !reset && _loaded;
    });
    try {
      final reader = HomeConversations(widget.controller.groupStore);
      late final List<Conversation> page;
      var drafts = _drafts;
      var groupCount = _groupCount;
      if (widget.groupsOnly) {
        final results = await Future.wait<Object>([
          reader.groups(
            after: reset || _items.isEmpty ? null : _items.last,
            limit: limit,
          ),
          reader.groupCount(),
        ]);
        page = results[0] as List<Conversation>;
        groupCount = results[1] as int;
      } else if (widget.profile != null) {
        page = await reader.forAi(
          widget.profile!.sender.id,
          offset: reset ? 0 : _items.length,
          limit: limit,
        );
      } else if (_root) {
        final results = await Future.wait([
          reader.chats(offset: reset ? 0 : _items.length, limit: limit),
          widget.controller.personalChatDrafts(),
        ]);
        page = results[0];
        drafts = results[1];
      } else {
        page = await (_tasks ? reader.recent : reader.chats)(
          offset: reset ? 0 : _items.length,
          limit: limit,
        );
      }
      final avatars = await Future.wait<Object>([
        reader.senders([...page, ...drafts]),
        widget.controller.groupStore.avatarMembers(
          page
              .where((item) => item.kind == ConversationKind.group)
              .map((item) => item.id)
              .toList(),
        ),
        reader.projects(page),
      ]);
      if (!mounted) return;
      setState(() {
        for (final item in page) {
          final read = _readCheckpoints[item.id];
          if (read == null) continue;
          // A read completed while this database snapshot was loading.
          // Keep later unread messages from a newer snapshot intact.
          if (item.isTask ||
              read.groupReadAt > item.groupReadAt ||
              (read.groupReadAt == item.groupReadAt &&
                  read.groupReadId.compareTo(item.groupReadId) > 0)) {
            _copyReadState(item, read);
          }
        }
        if (reset) {
          _items.clear();
          _senders.clear();
          _groups.clear();
          _projects.clear();
        }
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(page.where((item) => !existing.contains(item.id)));
        _readCheckpoints.removeWhere(
          (id, _) => !_items.any((item) => item.id == id),
        );
        _drafts = drafts;
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _projects.addAll(avatars[2] as Map<String, DevelopmentProject>);
        _more = page.length == limit;
        _loaded = true;
        _groupCount = groupCount;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('列表加载失败：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        if (_reloadPending) {
          _reloadPending = false;
          unawaited(reload());
        }
      }
    }
  }

  bool _opening = false;
  Future<void> _newConversation({
    ConversationMode mode = ConversationMode.normal,
  }) async {
    if (_opening) return;
    _opening = true;
    try {
      if (widget.profile != null) {
        final id = await widget.controller.openAiConversation(
          widget.profile!,
          newConversation: true,
          mode: mode,
        );
        if (!mounted) return;
        await openHomeConversation(
          context,
          widget.controller,
          id,
          waitForClose: true,
        );
        if (mounted) await reload();
        return;
      }
      final ai = await Navigator.push<AiProfile>(
        context,
        MaterialPageRoute(
          builder: (_) => AiContactsPage(
            controller: widget.controller,
            selectForConversation: true,
            returnSelection: true,
            conversationMode: mode,
          ),
        ),
      );
      if (!mounted || ai == null) return;
      final id = await widget.controller.openAiConversation(
        ai,
        newConversation: _tasks || mode != ConversationMode.normal,
        mode: mode,
      );
      if (!mounted) return;
      await openHomeConversation(
        context,
        widget.controller,
        id,
        waitForClose: true,
      );
      if (mounted) await reload();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('无法打开，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
    } finally {
      _opening = false;
    }
  }

  Future<void> _addFriend() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => AiContactEditor(controller: widget.controller),
      ),
    );
    if (!mounted || id == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AiContactPage(controller: widget.controller, senderId: id),
      ),
    );
  }

  Future<void> _group() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCreatePage(controller: widget.controller),
      ),
    );
    if (mounted && id != null)
      await openHomeConversation(
        context,
        widget.controller,
        id,
        resetStack: true,
      );
  }

  Future<void> _openTasks() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          RecentChatsPage(controller: widget.controller, tasksOnly: true),
    ),
  );

  Future<void> _openProjects() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ProjectsPage(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: widget.groupsOnly
          ? '群聊'
          : widget.profile == null
          ? (_tasks ? '任务' : '聊天')
          : '任务',

      onBack: widget.groupsOnly || _tasks ? () => Navigator.pop(context) : null,
      root: _root,
      leadingAction: !_root
          ? null
          : SettingsGlassAction(
              label: '项目',
              icon: Icons.folder_outlined,
              iconWidget: FileToolIcon(
                type: FileToolIconType.folder,
                color: SettingsGlassAction.foregroundColor(
                  context,
                  enabled: true,
                ),
              ),
              onPressed: _openProjects,
            ),
      actions: [
        if (!widget.groupsOnly)
          SettingsGlassActionSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundAction(
                  label: _tasks ? '搜索任务' : '搜索聊天',
                  icon: Icons.search_rounded,
                  iconWidget: const SidebarActionIcon(
                    type: SidebarActionIconType.search,
                  ),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversationSearchPage(
                        controller: widget.controller,
                        preparingGoal: () => false,
                        chatsOnly: !_tasks,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .12),
                ),
                Builder(
                  builder: (buttonContext) => RoundAction(
                    label: _tasks ? '新建任务' : '添加',
                    icon: Icons.add_rounded,
                    iconWidget: const SidebarActionIcon(
                      type: SidebarActionIconType.add,
                    ),
                    onPressed: () async {
                      if (_tasks) {
                        await _newConversation();
                        return;
                      }
                      final iconColor =
                          Theme.of(buttonContext).brightness == Brightness.dark
                          ? Theme.of(buttonContext).colorScheme.onSurfaceVariant
                          : const Color(0xff222222);
                      final action = await showHeaderActionMenu(
                        buttonContext,
                        items: [
                          (
                            value: 'friend',
                            label: '添加朋友',
                            icon: SettingsIcon(
                              type: SettingsIconType.contacts,
                              color: iconColor,
                            ),
                          ),
                          (
                            value: 'group',
                            label: '发起群聊',
                            icon: SidebarActionIcon(
                              type: SidebarActionIconType.group,
                              color: iconColor,
                            ),
                          ),
                          if (_root)
                            (
                              value: 'taskList',
                              label: '任务',
                              icon: SettingsIcon(
                                type: SettingsIconType.job,
                                color: iconColor,
                              ),
                            ),
                          (
                            value: 'tasks',
                            label: '定时任务',
                            icon: SettingsIcon(
                              type: SettingsIconType.tasks,
                              color: iconColor,
                            ),
                          ),
                        ],
                      );
                      if (!mounted) return;
                      if (action == 'friend') {
                        await _addFriend();
                      } else if (action == 'group') {
                        await _group();
                      } else if (action == 'taskList') {
                        await _openTasks();
                      } else if (action == 'tasks') {
                        await openScheduledTasks(context, widget.controller);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    body: !_loaded
        ? Center(
            child: _loading
                ? const ConversationListSkeleton()
                : TextButton(onPressed: reload, child: const Text('重试加载')),
          )
        : PaginationListener(
            hasMore: _more,
            loadMore: _load,
            child: AnimatedEntryList(
              animateChanges: false,
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.paddingOf(context).top +
                    SettingsAppBar.toolbarHeight +
                    8,
                12,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              empty: widget.groupsOnly
                  ? Center(child: EmptyDataView(title: '暂无群聊'))
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        MediaQuery.paddingOf(context).top +
                            SettingsAppBar.toolbarHeight +
                            8,
                        12,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _roundedTile(
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ),
                            horizontalTitleGap: 12,
                            leading: const ProfileAvatar(
                              style: AvatarStyle(icon: 'app_logo'),
                              name: 'Aurai',
                              size: 48,
                            ),
                            title: Text(_tasks ? '开始新任务' : '发起聊天'),
                            subtitle: Text(
                              _tasks ? '选择一位 AI 开始任务' : '选择一位 AI 开始聊天',
                            ),
                            onTap: _newConversation,
                          ),
                        ),
                      ),
                    ),
              children: [
                for (final item in _visibleItems)
                  ConversationMore(
                    key: ValueKey(item.id),
                    controller: widget.controller,
                    conversation: item,
                    showProjectAction: true,
                    onChanged: reload,
                    child: _tile(item),
                  ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (widget.groupsOnly && _items.isNotEmpty)
                  Padding(
                    key: const ValueKey('group-count'),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '共 $_groupCount 个群聊',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _tile(Conversation item) {
    final group = item.kind == ConversationKind.group;
    final sender = group ? null : _senders[item.defaultSenderId]!;
    return ConversationListTile(
      controller: widget.controller,
      conversation: item,
      project: _projects[item.projectId],
      displayName: item.isPersonalChat ? sender!.displayName : null,
      avatar: group
          ? GroupAvatar(groupId: item.id, members: _groups[item.id]!, size: 48)
          : ProfileAvatar(
              style: AvatarStyle(
                icon: sender!.avatarIcon,
                color: sender.avatarColor,
                path: sender.avatarPath,
              ),
              name: sender.name,
              size: 48,
            ),
      onTap: () async {
        try {
          await openHomeConversation(
            context,
            widget.controller,
            item.id,
            waitForClose: true,
          );
        } on Object catch (error) {
          if (mounted)
            ScaffoldMessenger.of(context).showToast(
              SnackBar(content: Text('无法打开记录，请重试：${errorMessage(error)}')),
              kind: ToastKind.error,
            );
        }
        if (mounted) reload();
      },
    );
  }

  Widget _roundedTile(Widget child, {bool pinned = false}) => Material(
    color: pinned
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
