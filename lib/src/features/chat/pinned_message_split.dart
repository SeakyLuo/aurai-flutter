import 'detail_split_layout.dart';
import 'pane_navigator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../storage/conversation_reader.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/interactive_message_store.dart';
import 'attachment_action_icon.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'settings_appearance.dart';

class PinnedMessageSplit extends StatefulWidget {
  const PinnedMessageSplit({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.onLocate,
    required this.messageBuilder,
    required this.child,
  });
  final ChatController controller;
  final String conversationId;
  final Future<void> Function(String) onLocate;
  final Widget Function(BuildContext, AgentMessage) messageBuilder;
  final Widget child;

  @override
  State<PinnedMessageSplit> createState() => PinnedMessageSplitState();
}

class PinnedMessageSplitState extends State<PinnedMessageSplit>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeInOutCubic,
  );
  late final StreamSubscription<String> _marks;
  late final StreamSubscription<String> _interactive;
  AgentMessage? _message;
  Widget? _details;
  GlobalKey<NavigatorState>? _detailsNavigator;
  Completer<bool?>? _detailsResult;
  int _request = 0;
  bool _open = false;
  final _paneNavigator = GlobalKey<PaneNavigatorState>();
  bool _returningFromConversation = false;

  Future<void> backFromConversation() async {
    setState(() => _returningFromConversation = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Navigator.of(context).maybePop();
    if (mounted) setState(() => _returningFromConversation = false);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMessage);
    _marks = GroupMessageMarks.changes.stream.listen((id) {
      if (_open && _details == null && id == widget.conversationId) _checkPin();
    });
    _interactive = InteractiveMessageStore.changes.stream.listen((id) {
      if (_open && _details == null && id == _message?.id) _load(id);
    });
  }

  void _syncMessage() {
    if (!_open ||
        _details != null ||
        widget.controller.activeConversation.id != widget.conversationId)
      return;
    final message = widget.controller.visibleMessages
        .where((message) => message.id == _message?.id)
        .firstOrNull;
    if (message == null) return;
    if (message.isSystem || !message.canView(MessageSender.localUser.id)) {
      close();
    } else if (!identical(message, _message)) {
      setState(() => _message = message);
    }
  }

  bool get supportsSplit => context.size!.width >= 600;

  Future<void> openProfile(MaterialPageRoute<void> route) async {
    if (_open && _details != null) {
      await _detailsNavigator!.currentState!.push<void>(route);
      return;
    }
    final pinned = _open ? _message : null;
    final conversationId = widget.conversationId;
    await openDetails(route.builder);
    if (mounted &&
        !_open &&
        _detailsResult == null &&
        pinned != null &&
        widget.conversationId == conversationId &&
        identical(_message, pinned)) {
      setState(() {
        _details = null;
        _open = true;
      });
      _animation.forward();
    }
  }

  Future<bool?> openDetails(WidgetBuilder builder) {
    FocusManager.instance.primaryFocus?.unfocus();
    _detailsResult?.complete(null);
    final result = Completer<bool?>();
    final navigator = GlobalKey<NavigatorState>();
    final route = MaterialPageRoute<bool>(builder: builder);
    _detailsResult = result;
    _detailsNavigator = navigator;
    ++_request;
    setState(() {
      _open = true;
      _details = Navigator(
        key: navigator,
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
          route,
        ],
        onGenerateRoute: (_) => null,
      );
    });
    route.popped.then((value) {
      if (!mounted || !identical(_detailsResult, result)) return;
      _detailsResult = null;
      close();
      result.complete(value);
    });
    _animation.forward();
    return result.future;
  }

  Future<void> open(String id) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _detailsResult?.complete(null);
    _detailsResult = null;
    setState(() => _details = null);
    await _load(id, opening: true);
  }

  Future<void> _load(String id, {bool opening = false}) async {
    final request = ++_request;
    final groupId = widget.conversationId;
    await runUiAction(context, () async {
      final root = await getApplicationSupportDirectory();
      final messages = await ConversationReader(
        widget.controller.groupStore.database,
        '${root.path}/message_images',
      ).messages(groupId, throughMessageId: id, includeMessageId: id, limit: 1);
      if (!mounted || request != _request) return;
      final message = messages.where((message) => message.id == id).firstOrNull;
      if (message == null ||
          message.isSystem ||
          !message.canView(MessageSender.localUser.id)) {
        close();
        throw StateError('消息已删除、撤回或不可见');
      }
      setState(() {
        _message = message;
        if (opening) _open = true;
      });
      if (opening) _animation.forward();
    });
  }

  Future<void> _checkPin() => runUiAction(context, () async {
    final groupId = widget.conversationId;
    final pin = await GroupMessageMarks(
      widget.controller.groupStore,
    ).pinned(groupId);
    if (!mounted || groupId != widget.conversationId) return;
    if (pin == null || pin['id'] != _message?.id) close();
  });

  void close() {
    ++_request;
    _detailsResult?.complete(null);
    _detailsResult = null;
    setState(() => _open = false);
    _animation.reverse().then((_) {
      if (mounted && !_open && _animation.isDismissed) {
        setState(() => _details = null);
      }
    });
  }

  @override
  void didUpdateWidget(PinnedMessageSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      ++_request;
      _open = false;
      _message = null;
      _details = null;
      _detailsResult?.complete(null);
      _detailsResult = null;
      _animation.value = 0;
    }
  }

  Future<void> _menu(BuildContext anchor) async {
    final id = _message!.id;
    final groupId = widget.conversationId;
    final result = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'unpin',
          label: '取消置顶',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.removeTop,
          ),
        ),
      ],
    );
    if (!mounted || result != 'unpin') return;
    await runUiAction(
      context,
      () => GroupMessageMarks(
        widget.controller.groupStore,
      ).pin(groupId, id, false),
    );
  }

  Widget _detail(BuildContext context, {required bool wide}) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '置顶详情',
      onBack: close,
      actions: [
        SettingsGlassActionSurface(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundAction(
                label: '定位',
                icon: Icons.my_location,
                iconWidget: AttachmentActionIcon(
                  type: AttachmentActionIconType.locate,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () {
                  final id = _message!.id;
                  if (!wide) close();
                  widget.onLocate(id);
                },
              ),
              const SizedBox(height: 20, child: VerticalDivider(width: 1)),
              Builder(
                builder: (anchor) => RoundAction(
                  label: '更多',
                  icon: Icons.more_vert_rounded,
                  onPressed: () => _menu(anchor),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    body: SettingsPageBody(
      child: ListView(
        padding: settingsPagePadding(
          context,
          const EdgeInsets.only(top: 12, bottom: 24),
        ),
        children: [widget.messageBuilder(context, _message!)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open || _returningFromConversation,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop &&
          _open &&
          !_returningFromConversation &&
          !_paneNavigator.currentState!.hasOverlayRoute) {
        if (_details != null) {
          _detailsNavigator!.currentState!.maybePop();
        } else {
          close();
        }
      }
    },
    child: DetailSplitLayout(
      animation: _curve,
      opened: _open,
      child: PaneNavigator(
        key: _paneNavigator,
        handleBack: !_returningFromConversation,
        child: widget.child,
      ),
      detailBuilder: _message != null || _details != null
          ? (context, wide) => Stack(
              fit: StackFit.expand,
              children: [
                if (_message != null)
                  Offstage(
                    key: const ValueKey('pinned-message'),
                    offstage: _details != null,
                    child: TickerMode(
                      enabled: _details == null,
                      child: _detail(context, wide: wide),
                    ),
                  ),
                if (_details != null) _details!,
              ],
            )
          : null,
    ),
  );

  @override
  void dispose() {
    _detailsResult?.complete(null);
    widget.controller.removeListener(_syncMessage);
    _marks.cancel();
    _interactive.cancel();
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }
}
