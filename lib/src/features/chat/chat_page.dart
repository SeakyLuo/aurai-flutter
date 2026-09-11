import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'capability_sheet.dart';
import 'chat_controller.dart';
import 'chat_widgets.dart';
import 'chat_header.dart';
import 'glass_surface.dart';
import 'message_item.dart';
import 'model_settings_sheet.dart';
import 'conversations_sheet.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller});

  final ChatController controller;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  var _canSend = false;
  var _followOutput = true;
  PendingConfirmation? _shownConfirmation;
  late String _conversationId;
  Timer? _draftTimer;
  bool _preparingGoal = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.controller.activeConversation.id;
    _textController.text = widget.controller.activeConversation.draft;
    _canSend = _textController.text.trim().isNotEmpty;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _draftTimer?.cancel();
      unawaited(_saveDraft());
    }
    if (state == AppLifecycleState.resumed) {
      widget.controller.checkAccessibilityReturn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final showProgress =
        controller.isBusy ||
        controller.pendingGoal != null ||
        controller.steps.isNotEmpty;
    final progressBeforeFinalAnswer =
        showProgress &&
        !controller.isBusy &&
        controller.pendingGoal == null &&
        controller.messages.isNotEmpty &&
        controller.messages.last.role == AgentMessageRole.assistant;
    final itemCount = controller.messages.length + (showProgress ? 1 : 0);
    final progressKey = ValueKey(
      'progress:${controller.activeConversation.id}',
    );
    final childIndices = <Key, int>{
      for (var i = 0; i < controller.messages.length; i++)
        ValueKey(
          controller.messages[i].id,
        ): progressBeforeFinalAnswer && i == controller.messages.length - 1
            ? 0
            : itemCount - 1 - i,
      if (showProgress) progressKey: progressBeforeFinalAnswer ? 1 : 0,
    };
    return BackdropGroup(
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: ChatHeader(
          onMenu: _openConversations,
          onNew: () => _changeConversation(),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            enabled: !controller.isBusy,
            canSend: _canSend,
            stopping: controller.runState == ChatRunState.stopping,
            onSend: _send,
            onStop: _stop,
          ),
        ),
        body: Builder(
          builder: (context) {
            final top = MediaQuery.paddingOf(context).top;
            final bottom = MediaQuery.paddingOf(context).bottom;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: controller.messages.isEmpty && !showProgress
                          ? Padding(
                              padding: EdgeInsets.only(
                                top: top,
                                bottom: bottom,
                              ),
                              child: EmptyConversation(
                                onUseExample: _useExample,
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: _trackScroll,
                              child: ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                findChildIndexCallback: (key) =>
                                    childIndices[key],
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.only(
                                  top: top + 12,
                                  bottom: bottom + 16,
                                ),
                                itemCount: itemCount,
                                itemBuilder: (_, reverseIndex) {
                                  final index = itemCount - 1 - reverseIndex;
                                  if (progressBeforeFinalAnswer) {
                                    if (index < controller.messages.length - 1)
                                      return MessageItem(
                                        key: ValueKey(
                                          controller.messages[index].id,
                                        ),
                                        message: controller.messages[index],
                                      );
                                    if (index == controller.messages.length - 1)
                                      return KeyedSubtree(
                                        key: progressKey,
                                        child: _buildProgress(controller),
                                      );
                                    return MessageItem(
                                      key: ValueKey(
                                        controller.messages.last.id,
                                      ),
                                      message: controller.messages.last,
                                    );
                                  }
                                  if (index < controller.messages.length)
                                    return MessageItem(
                                      key: ValueKey(
                                        controller.messages[index].id,
                                      ),
                                      message: controller.messages[index],
                                    );
                                  return KeyedSubtree(
                                    key: progressKey,
                                    child: _buildProgress(controller),
                                  );
                                },
                              ),
                            ),
                    ),
                    if (!_followOutput && controller.messages.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottom + 8,
                        child: Center(
                          child: GlassSurface(
                            radius: 28,
                            child: RoundAction(
                              label: '回到底部',
                              onPressed: _scrollToBottom,
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress(ChatController controller) => ExecutionProgress(
    state: controller.runState,
    steps: controller.steps,
    needsConfiguration: controller.needsConfiguration,
    hasPendingGoal: controller.pendingGoal != null,
    onContinue: _continuePending,
    onRetry: _continuePending,
    accessibilityRequestPending: controller.accessibilityRequestPending,
    onEnableAccessibility: _enableAccessibility,
    onCancelAccessibility: controller.cancelAccessibilityRequest,
    onBatterySettings: _openBatterySettings,
  );

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final conversation = widget.controller.activeConversation;
    if (_conversationId != conversation.id) {
      _draftTimer?.cancel();
      _conversationId = conversation.id;
      _textController.text = conversation.draft;
      _textController.selection = TextSelection.collapsed(
        offset: conversation.draft.length,
      );
      _followOutput = true;
      _focusNode.unfocus();
    }
    setState(() {});
    final confirmation = widget.controller.pendingConfirmation;
    if (confirmation != null && confirmation != _shownConfirmation) {
      _shownConfirmation = confirmation;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showConfirmation(confirmation),
      );
    }
    if (_followOutput) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _enableAccessibility() async {
    await widget.controller.openAccessibilitySettings();
  }

  Future<void> _openBatterySettings() async {
    await widget.controller.openBatterySettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在“电池”或“后台耗电管理”中允许 Aurai 后台运行')),
      );
    }
  }

  Future<void> _showConfirmation(PendingConfirmation request) async {
    if (!mounted) return;
    final arguments = request.call.arguments;
    final detail = switch (request.call.name) {
      'shell' => '将以 Aurai 自身权限执行命令：\n${arguments['command']}',
      'startIntent' => '将启动 Android 操作：\n${_intentSummary(arguments)}',
      'act' when arguments['action'] == 'inputText' =>
        '将输入文字：\n${arguments['text']}',
      'act' => switch (arguments['action']) {
        'click' => '将点击当前屏幕中选定的控件。',
        'scroll' => '将滚动当前页面。',
        'back' => '将返回上一页。',
        'home' => '将返回手机主屏幕。',
        _ => '将操作当前屏幕中选定的控件。',
      },
      _ =>
        request.definition.confirmationDescriptionFor(arguments) ??
            request.definition.description,
    };
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('允许 Aurai 执行？'),
        content: SelectableText(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              request.definition.taskScopedConfirmation ? '本任务允许' : '允许一次',
            ),
          ),
        ],
      ),
    );
    widget.controller.resolveConfirmation(approved == true);
    _shownConfirmation = null;
  }

  String _intentSummary(Map<String, Object?> arguments) => <String>[
    'Action: ${arguments['action']}',
    if (arguments['data'] != null) 'Data: ${arguments['data']}',
    if (arguments['mimeType'] != null) 'Type: ${arguments['mimeType']}',
    if (arguments['packageName'] != null) 'App: ${arguments['packageName']}',
    if (arguments['extras'] != null) 'Extras: ${arguments['extras']}',
  ].join('\n');

  void _onTextChanged() {
    widget.controller.activeConversation.draft = _textController.text;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
    final canSend = _textController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  Future<void> _saveDraft() async {
    try {
      await widget.controller.saveDraft();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('草稿保存失败，请稍后重试')));
      }
    }
  }

  Future<void> _openConversations() async {
    _focusNode.unfocus();
    var choice = await showConversationsSheet(context, widget.controller);
    if (!mounted || choice == null) return;
    if (choice.action == ConversationAction.settings) {
      choice = await showConversationSettings(context, widget.controller);
    }
    if (!mounted || choice == null) return;
    switch (choice.action) {
      case ConversationAction.settings:
        break;
      case ConversationAction.create:
        await _changeConversation();
      case ConversationAction.select:
        await _changeConversation(choice.id);
      case ConversationAction.model:
        await _openSettings(continueAfterSave: false);
      case ConversationAction.capabilities:
        await CapabilitySheet.show(context, widget.controller);
      case ConversationAction.clear:
        await _confirmClear();
    }
  }

  Future<void> _changeConversation([String? id]) async {
    final controller = widget.controller;
    if (id == controller.activeConversation.id) return;
    if (controller.isBusy || _preparingGoal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先停止当前任务，再新建或切换会话')));
      return;
    }
    _draftTimer?.cancel();
    try {
      if (id == null) {
        await controller.createConversation();
      } else {
        await controller.selectConversation(id);
      }
      if (!mounted) return;
      _followOutput = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
        if (id == null) _focusNode.requestFocus();
      });
      setState(() {});
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话保存失败，请稍后重试')));
      }
    }
  }

  bool _trackScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical)
      return false;
    if (notification is ScrollUpdateNotification ||
        notification is UserScrollNotification) {
      final nearBottom = notification.metrics.extentBefore < 72;
      if (nearBottom != _followOutput) {
        setState(() => _followOutput = nearBottom);
      }
    }
    return false;
  }

  void _useExample(String example) {
    _textController.text = example;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final conversationId = widget.controller.activeConversation.id;
    final goal = _textController.text.trim();
    if (goal.isEmpty || widget.controller.isBusy || _preparingGoal) {
      return;
    }
    _preparingGoal = true;
    try {
      if (!await _ensureBackgroundRunReady()) return;
    } finally {
      _preparingGoal = false;
    }
    _textController.clear();
    _focusNode.unfocus();
    _followOutput = true;
    try {
      final needsSettings = await widget.controller.submitGoal(goal);
      if (needsSettings && mounted) {
        await _openSettings(continueAfterSave: true);
      }
    } on Object {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice();
    }
  }

  Future<void> _continuePending() async {
    final conversationId = widget.controller.activeConversation.id;
    if (_preparingGoal) return;
    if (widget.controller.needsConfiguration) {
      await _openSettings(continueAfterSave: true);
      return;
    }
    _preparingGoal = true;
    try {
      if (!await _ensureBackgroundRunReady()) return;
    } finally {
      _preparingGoal = false;
    }
    try {
      await widget.controller.continuePending();
    } on Object {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice();
    }
  }

  Future<bool> _ensureBackgroundRunReady() async {
    var readiness = await widget.controller.getBackgroundRunReadiness();
    final requestedBefore = readiness['notificationRequestedBefore'] == true;
    if (readiness['notificationGranted'] == true ||
        (requestedBefore && readiness['accessibilityAvailable'] == true)) {
      return true;
    }
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('允许 Aurai 在后台执行？'),
        content: Text(
          requestedBefore
              ? '跨 App 操作时，需要通知或无障碍悬浮胶囊让你随时看到并停止任务。请开启其中一项。'
              : '排查过程中 Aurai 会切换到 VPN、设置或 ChatGPT。允许通知后，任务离开当前页面仍可继续，你也能随时停止。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(requestedBefore ? '前往设置' : '允许通知'),
          ),
        ],
      ),
    );
    if (allow != true || !mounted) return false;
    if (requestedBefore) {
      await widget.controller.openNotificationSettings();
      return false;
    }
    await widget.controller.requestNotificationPermission();
    readiness = await widget.controller.getBackgroundRunReadiness();
    if (readiness['notificationGranted'] == true ||
        readiness['accessibilityAvailable'] == true) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未获得后台状态权限，任务尚未开始')));
    }
    return false;
  }

  Future<void> _stop() async {
    await widget.controller.stop();
  }

  void _showRunNotice() {
    if (!mounted) {
      return;
    }
    final stopped = widget.controller.runState == ChatRunState.cancelled;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stopped ? '任务已停止' : widget.controller.errorDetail ?? '任务没有完成，可以重试',
        ),
      ),
    );
  }

  Future<void> _openSettings({required bool continueAfterSave}) async {
    if (widget.controller.isBusy) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先停止当前任务，再修改模型')));
      return;
    }
    final saved = await ModelSettingsSheet.show(
      context,
      controller: widget.controller,
      continueAfterSave: continueAfterSave,
    );
    if (saved && continueAfterSave && mounted) {
      await _continuePending();
    }
  }

  Future<void> _confirmClear() async {
    if (widget.controller.isBusy || _preparingGoal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先停止当前任务')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空当前会话？'),
        content: const Text('这会删除当前会话的消息，其他会话会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.clearConversation();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前会话已清空')));
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (!_followOutput) {
      setState(() => _followOutput = true);
    }
  }
}
