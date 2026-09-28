import '../../storage/development_projects.dart';
import '../../utils/widget_utils.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/ai_profile.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_controller.dart';
import 'ai_contacts_page.dart';
import 'attachment_source_menu.dart';
import 'chat_widgets.dart';
import '../../app/ui_action.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import '../../platform/message_file_store.dart';
import '../../platform/message_image_store.dart';
import 'conversation_list_tile.dart';
import 'conversation_list_skeleton.dart';
import 'conversation_more.dart';
import 'group_avatar.dart';
import 'home_navigation.dart';
import 'profile_avatar.dart';
import 'pagination_listener.dart';
import 'file_tool_icon.dart';
import 'project_editor_page.dart';
import 'project_list_tile.dart';
import 'project_actions.dart';
import 'menu_press_highlight.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'send_favorite_page.dart';
import 'conversation_search_page.dart';
import 'sidebar_action_icon.dart';
import 'glass_surface.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<DevelopmentProject>? _projects;
  Set<String> _unreadProjectIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await widget.controller.projects.list();
    final unreadProjectIds = await widget.controller.projects.unreadProjectIds(
      projects.map((project) => project.id).toList(),
    );
    if (mounted) {
      setState(() {
        _projects = projects;
        _unreadProjectIds = unreadProjectIds;
      });
    }
  }

  Future<void> _add() async {
    final project = await Navigator.push<DevelopmentProject>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectEditorPage(controller: widget.controller),
      ),
    );
    if (!mounted || project == null) return;
    await _load();
    if (mounted) await _open(project);
  }

  Future<void> _open(DevelopmentProject project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProjectPage(controller: widget.controller, project: project),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _actions(
    BuildContext anchorContext,
    DevelopmentProject project,
  ) async {
    final result = await showProjectActions(
      anchorContext,
      widget.controller,
      project,
      hasUnread: _unreadProjectIds.contains(project.id),
    );
    if (mounted && result != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '项目',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '添加项目',
            icon: Icons.add_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.add),
            onPressed: _add,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: projects == null
              ? const SizedBox.shrink()
              : projects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FileToolIcon(type: FileToolIconType.folder),
                      const SizedBox(height: 16),
                      const Text(
                        '还没有项目',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '项目会把工作目录和相关会话放在一起。',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      WidgetUtils.primaryButton(text: '添加项目', onPressed: _add),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top +
                        SettingsAppBar.toolbarHeight +
                        12,
                    12,
                    24,
                  ),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return Builder(
                      builder: (tileContext) => MenuPressHighlight(
                        onLongPressStart: (_) => _actions(tileContext, project),
                        borderRadius: BorderRadius.circular(22),
                        child: ProjectListTile(
                          project: project,
                          unread: _unreadProjectIds.contains(project.id),
                          onTap: () => _open(project),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class ProjectPage extends StatefulWidget {
  const ProjectPage({
    super.key,
    required this.controller,
    required this.project,
  });
  final ChatController controller;
  final DevelopmentProject project;

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  late DevelopmentProject _project = widget.project;
  List<Conversation>? _conversations;
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  bool _loading = false, _more = true;
  bool _opening = false;
  final _message = TextEditingController();
  final _focusNode = FocusNode();
  AiProfile? _recipient;
  String? _draftConversationId;
  @override
  void initState() {
    super.initState();
    _load();
    _loadRecipient();
    widget.controller.addListener(_controllerChanged);
    _message.addListener(_messageChanged);
  }

  Future<void> _loadRecipient() async {
    final recipient = await widget.controller.groupStore.loadAi(
      _project.defaultSenderId,
    );
    if (mounted) setState(() => _recipient = recipient);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _message.removeListener(_messageChanged);
    _message.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _controllerChanged() {
    if (mounted &&
        _draftConversationId == widget.controller.activeConversation.id) {
      setState(() {});
    }
  }

  void _messageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    await runUiAction(context, () async {
      final reader = HomeConversations(widget.controller.groupStore);
      final page = await reader.forProject(
        _project.id,
        offset: more ? _conversations!.length : 0,
      );
      final avatars = await Future.wait<Object>([
        reader.senders(page),
        widget.controller.groupStore.avatarMembers(
          page
              .where((item) => item.kind == ConversationKind.group)
              .map((item) => item.id)
              .toList(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        if (!more) {
          _senders.clear();
          _groups.clear();
        }
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _conversations = more ? [..._conversations!, ...page] : page;
        _more = page.length == HomeConversations.pageSize;
      });
    });
    if (mounted) setState(() => _loading = false);
  }

  Widget _conversationTile(Conversation item) {
    final group = item.kind == ConversationKind.group;
    final sender = group ? null : _senders[item.defaultSenderId]!;
    return ConversationMore(
      key: ValueKey(item.id),
      controller: widget.controller,
      conversation: item,
      onChanged: _load,
      child: ConversationListTile(
        controller: widget.controller,
        conversation: item,
        avatar: group
            ? GroupAvatar(members: _groups[item.id]!, size: 48)
            : ProfileAvatar(
                style: AvatarStyle(
                  icon: sender!.avatarIcon,
                  color: sender.avatarColor,
                  path: sender.avatarPath,
                ),
                name: sender.name,
                size: 48,
              ),
        onTap: () {
          if (!_opening) _openConversation(item.id);
        },
      ),
    );
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    final recipient = _recipient;
    final controller = widget.controller;
    final hasAttachments =
        _draftConversationId == controller.activeConversation.id &&
        (controller.draftImages.isNotEmpty || controller.draftFiles.isNotEmpty);
    if ((message.isEmpty && !hasAttachments) || _opening || recipient == null) {
      return;
    }
    _focusNode.unfocus();
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _ensureDraft();
      controller.updateDraft(message);
      final submission = controller.submitGoal(message);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      await submission;
    } on Object catch (error) {
      messenger.showGlassSnackBar(
        SnackBar(content: Text('无法发送消息，请重试：${errorMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _ensureDraft() async {
    final controller = widget.controller;
    if (_draftConversationId == controller.activeConversation.id) return;
    await controller.createProjectConversation(
      _project,
      senderId: _recipient!.sender.id,
    );
    _draftConversationId = controller.activeConversation.id;
    if (_message.text.isNotEmpty) {
      controller.updateDraft(_message.text);
      await controller.saveDraft();
    }
  }

  Future<void> _openSendMenu(BuildContext buttonContext) async {
    final source = await showAttachmentSourceMenu(
      buttonContext,
      allowFriendSelection: true,
      friendIcon: ProfileAvatar(
        style: AvatarStyle(
          icon: _recipient!.sender.avatarIcon,
          color: _recipient!.sender.avatarColor,
          path: _recipient!.sender.avatarPath,
        ),
        name: _recipient!.sender.name,
        size: 24,
      ),
    );
    if (!mounted || source == null) return;
    if (source == AttachmentSource.friend) {
      await _selectRecipient();
      return;
    }
    try {
      await _ensureDraft();
      switch (source) {
        case AttachmentSource.gallery:
          if (widget.controller.draftImages.length ==
              MessageImageStore.maxImages) {
            _notice('每条消息最多添加 4 张图片，请先移除一张');
            return;
          }
          await widget.controller.addImages(ImageSource.gallery);
        case AttachmentSource.camera:
          if (widget.controller.draftImages.length ==
              MessageImageStore.maxImages) {
            _notice('每条消息最多添加 4 张图片，请先移除一张');
            return;
          }
          await widget.controller.addImages(ImageSource.camera);
        case AttachmentSource.file:
          if (widget.controller.draftFiles.length ==
              MessageFileStore.maxFiles) {
            _notice('每条消息最多添加 10 个文件');
            return;
          }
          await widget.controller.addFiles();
        case AttachmentSource.favorite:
          _focusNode.unfocus();
          final sent = await showSendFavoritePage(context, widget.controller);
          if (mounted && sent == true) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        case AttachmentSource.friend:
          return;
      }
    } on Object catch (error) {
      if (mounted) _notice('附件添加失败，请重试：${errorMessage(error)}');
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Future<void> _selectRecipient() async {
    final recipient = await Navigator.push<AiProfile>(
      context,
      MaterialPageRoute<AiProfile>(
        builder: (_) => AiContactsPage(
          controller: widget.controller,
          selectForConversation: true,
          returnSelection: true,
        ),
      ),
    );
    if (!mounted || recipient == null) return;
    if (_draftConversationId == widget.controller.activeConversation.id) {
      await widget.controller.setActiveDraftSender(recipient.sender.id);
    }
    if (mounted) {
      setState(() {
        _recipient = recipient;
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _openConversation(String id) async {
    setState(() => _opening = true);
    try {
      await openHomeConversation(
        context,
        widget.controller,
        id,
        waitForClose: true,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _showMore(BuildContext anchorContext) async {
    final result = await showProjectActions(
      anchorContext,
      widget.controller,
      _project,
      allowHomeShortcut: true,
    );
    if (!mounted) return;
    if (result == ProjectActionResult.removed) {
      Navigator.pop(context);
      return;
    }
    if (result == null) return;
    final project = await widget.controller.projects.read(_project.id);
    if (mounted) {
      setState(() => _project = project);
      await _load();
    }
  }

  Future<void> _searchProject() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ConversationSearchPage(
        controller: widget.controller,
        preparingGoal: () => false,
        projectId: _project.id,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final conversations = _conversations;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _project.name,
        onBack: _opening ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassActionSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundAction(
                  label: '搜索项目',
                  icon: Icons.search_rounded,
                  iconWidget: const SidebarActionIcon(
                    type: SidebarActionIconType.search,
                  ),
                  onPressed: _opening ? null : _searchProject,
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
                    label: '更多',
                    icon: Icons.more_horiz_rounded,
                    iconWidget: const SettingsIcon(type: SettingsIconType.more),
                    onPressed: _opening ? null : () => _showMore(buttonContext),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: conversations == null
                    ? const ConversationListSkeleton()
                    : conversations.isEmpty
                    ? const SizedBox.shrink()
                    : PaginationListener(
                        hasMore: _more && !_loading,
                        loadMore: () => _load(more: true),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            MediaQuery.paddingOf(context).top +
                                SettingsAppBar.toolbarHeight +
                                12,
                            12,
                            24,
                          ),
                          itemCount: conversations.length + (_loading ? 1 : 0),
                          itemBuilder: (context, index) =>
                              index == conversations.length
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _conversationTile(conversations[index]),
                        ),
                      ),
              ),
            ),
          ),
          ChatComposer(
            controller: _message,
            focusNode: _focusNode,
            hintText: _recipient == null
                ? '正在准备会话'
                : '给 ${_recipient!.sender.name} 发消息',
            enabled: true,
            draftEnabled: !_opening && _recipient != null,
            canSend:
                _message.text.trim().isNotEmpty ||
                (_draftConversationId ==
                        widget.controller.activeConversation.id &&
                    (widget.controller.draftImages.isNotEmpty ||
                        widget.controller.draftFiles.isNotEmpty)),
            stopping: false,
            submitting: _opening,
            onSend: _send,
            onResume: () {},
            canResume: false,
            onStop: () {},
            onAddImages: _openSendMenu,
            images:
                _draftConversationId == widget.controller.activeConversation.id
                ? widget.controller.draftImages
                : const [],
            files:
                _draftConversationId == widget.controller.activeConversation.id
                ? widget.controller.draftFiles
                : const [],
            onRemoveImage: (image) async {
              try {
                await widget.controller.removeDraftImage(image);
              } on Object catch (error) {
                if (mounted) _notice('附件移除失败，请重试：${errorMessage(error)}');
              }
            },
            onRemoveFile: (file) async {
              try {
                await widget.controller.removeDraftFile(file);
              } on Object catch (error) {
                if (mounted) _notice('附件移除失败，请重试：${errorMessage(error)}');
              }
            },
            addingImages:
                _draftConversationId ==
                    widget.controller.activeConversation.id &&
                widget.controller.addingImages,
          ),
        ],
      ),
    );
  }
}
