import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/message_image.dart';
import '../../platform/message_image_store.dart';
import 'image_attachments.dart';

import 'settings_page.dart';
import 'search_aurora_background.dart';
import 'accessibility_request_sheet.dart';
import 'chat_controller.dart';
import 'chat_widgets.dart';
import 'chat_header.dart';
import 'drawer_drag_region.dart';
import 'thinking_indicator.dart';
import 'chat_viewport.dart';
import 'message_item.dart';
import 'jump_to_bottom_button.dart';
import 'chat_timeline.dart';
import 'model_settings_sheet.dart';
import 'conversations_sheet.dart';
import 'conversation_search_page.dart';

part 'chat_session_actions.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller});

  final ChatController controller;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  var _viewportKey = GlobalKey<ChatViewportState>();
  final _scrollBookmarks = <String, ChatScrollBookmark>{};
  var _canSend = false;
  var _followOutput = true;
  bool _contentBelow = false;
  bool _positionSentMessage = false;
  String? _beforeSentMessageId;
  String? _sentMessageId;
  PendingConfirmation? _shownConfirmation;
  late String _conversationId;
  Timer? _draftTimer;
  bool _preparingGoal = false;
  bool _accessibilitySheetShowing = false;
  bool _markReadScheduled = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.controller.activeConversation.id;
    _textController.text = widget.controller.activeConversation.draft;
    _canSend = _textController.text.trim().isNotEmpty;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _loadImages();
    });
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
      _scheduleMarkRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context)!.isCurrent) _scheduleMarkRead();
    final controller = widget.controller;
    final conversationId = controller.activeConversation.id;
    final timeline = buildChatTimeline(
      controller,
      preparingGoal: () => _preparingGoal,
      continueReply: _continuePending,
    );
    final showProgress =
        (controller.isBusy && controller.runState != ChatRunState.idle) ||
        controller.pendingGoal != null ||
        controller.runState == ChatRunState.failed ||
        controller.runState == ChatRunState.cancelled ||
        controller.runState == ChatRunState.interrupted;
    if (showProgress) {
      timeline.add(
        ChatTimelineEntry(
          'progress:${controller.activeConversation.id}',
          (_) => _buildProgress(controller),
        ),
      );
    }
    return AbsorbPointer(
      absorbing: controller.changingConversation,
      child: BackdropGroup(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: timeline.isEmpty ? Colors.transparent : null,
          drawer: ConversationsDrawer(
            controller: controller,
            onChoose: _chooseConversationAction,
          ),
          drawerEnableOpenDragGesture: !controller.addingImages,
          onDrawerChanged: (opened) {
            if (opened) _focusNode.unfocus();
            if (!opened) _scheduleMarkRead();
          },
          extendBody: true,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: ChatHeader(
            onMenu: _openConversations,
            controller: controller,
            beforeDelete: _beforeDeleteConversation,
          ),
          bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ChatComposer(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !controller.isBusy,
                canSend: _canSend || controller.draftImages.isNotEmpty,
                images: controller.draftImages,
                addingImages: controller.addingImages,
                onAddImages: _addImages,
                onRemoveImage: _removeImage,
                stopping: controller.runState == ChatRunState.stopping,
                onSend: _send,
                canResume:
                    controller.runState == ChatRunState.cancelled &&
                    controller.pendingGoal != null,
                onResume: _continuePending,
                onStop: _stop,
              ),
            ),
          ),
          body: DrawerDragRegion(
            onOpen: _openConversations,
            builder: (context) {
              final top = MediaQuery.paddingOf(context).top;
              final bottom = MediaQuery.paddingOf(context).bottom;
              return Stack(
                children: [
                  if (timeline.isEmpty)
                    const Positioned.fill(child: SearchAuroraBackground()),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: timeline.isEmpty
                                ? EmptyConversation(
                                    contentPadding: EdgeInsets.only(
                                      top: top,
                                      bottom: bottom,
                                    ),
                                    onUseExample: _useExample,
                                  )
                                : KeyedSubtree(
                                    key: PageStorageKey(
                                      'conversation:$_conversationId',
                                    ),
                                    child: ChatViewport(
                                      key: _viewportKey,
                                      entries: timeline,
                                      bookmark:
                                          _scrollBookmarks[_conversationId],
                                      followOutput: _followOutput,
                                      sentMessageId: _sentMessageId,
                                      sentMessageTop:
                                          top + 8 - MessageItem.userTopMargin,
                                      onContentBelowChanged: (value) {
                                        if (mounted &&
                                            _conversationId == conversationId) {
                                          setState(() => _contentBelow = value);
                                        }
                                      },
                                      padding: EdgeInsets.only(
                                        top: top + 12,
                                        bottom: bottom + 16,
                                      ),
                                      hasEarlierMessages: controller
                                          .activeConversation
                                          .hasEarlierMessages,
                                      loadEarlierMessages:
                                          controller.loadEarlierMessages,
                                      onBookmark: (bookmark) =>
                                          _scrollBookmarks[conversationId] =
                                              bookmark,
                                      onFollowOutputChanged: (value) {
                                        if (mounted)
                                          setState(() => _followOutput = value);
                                      },
                                      summaryOwners: chatSummaryOwners(
                                        controller,
                                      ),
                                    ),
                                  ),
                          ),
                          if (controller.changingConversation)
                            Positioned.fill(
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.81),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: ThinkingIndicator(label: '正在打开会话'),
                                  ),
                                ),
                              ),
                            ),
                          if (!_followOutput &&
                              _contentBelow &&
                              timeline.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: bottom + 8,
                              child: Center(
                                child: JumpToBottomButton(
                                  streaming:
                                      controller.streamingMessageId != null,
                                  onPressed: _scrollToBottom,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ChatController controller) => ExecutionProgress(
    state: controller.runState,
    steps: controller.steps,
    needsConfiguration: controller.needsConfiguration,
    hasPendingGoal: controller.pendingGoal != null,
    replying: controller.streamingMessageId != null,
    onContinue: _continuePending,
    onRetry: _continuePending,
    accessibilityRequestPending: controller.accessibilityRequestPending,
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
      _viewportKey = GlobalKey<ChatViewportState>();
      _contentBelow = false;
      _sentMessageId = _scrollBookmarks[conversation.id]?.replyAnchorId;
      _textController.text = conversation.draft;
      _textController.selection = TextSelection.collapsed(
        offset: conversation.draft.length,
      );
      _followOutput = _scrollBookmarks[conversation.id]?.followOutput ?? true;
      _focusNode.unfocus();
    }
    if (_positionSentMessage &&
        conversation.messages.isNotEmpty &&
        conversation.messages.last.id != _beforeSentMessageId) {
      _positionSentMessage = false;
      _sentMessageId = conversation.messages.last.id;
      _followOutput = false;
    }
    if (widget.controller.isBusy &&
        conversation.draft.isEmpty &&
        _textController.text.isNotEmpty) {
      _textController.removeListener(_onTextChanged);
      _textController.clear();
      _textController.addListener(_onTextChanged);
      _canSend = false;
    } else if (!widget.controller.isBusy &&
        conversation.draft != _textController.text) {
      _textController.removeListener(_onTextChanged);
      _textController.text = conversation.draft;
      _textController.addListener(_onTextChanged);
      _canSend = conversation.draft.trim().isNotEmpty;
    }
    setState(() {});
    if (widget.controller.accessibilityRequestPending &&
        !_accessibilitySheetShowing) {
      _accessibilitySheetShowing = true;
      _focusNode.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (mounted && widget.controller.accessibilityRequestPending) {
            await showAccessibilityRequestSheet(context, widget.controller);
          }
        } finally {
          _accessibilitySheetShowing = false;
        }
      });
    }
    final confirmation = widget.controller.pendingConfirmation;
    if (confirmation != null && confirmation != _shownConfirmation) {
      _shownConfirmation = confirmation;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showConfirmation(confirmation),
      );
    }
    if (_followOutput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_followOutput) return;
        _viewportKey.currentState?.scrollToBottom();
      });
    }
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
    final detail =
        request.definition.confirmationDescriptionFor(arguments) ??
        switch (request.call.name) {
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

  void _openConversations() {
    if (_imageOperationPending()) return;
    _focusNode.unfocus();
    _scaffoldKey.currentState!.openDrawer();
  }

  Future<void> _chooseConversationAction(
    ConversationSelection selection,
  ) async {
    _scaffoldKey.currentState!.closeDrawer();
    final choice = selection;
    if (choice.action == ConversationAction.search) {
      final selection = await Navigator.of(context).push<ConversationSelection>(
        MaterialPageRoute(
          builder: (_) => ConversationSearchPage(
            controller: widget.controller,
            preparingGoal: () => _preparingGoal,
          ),
        ),
      );
      if (!mounted || selection == null) return;
      await _chooseConversationAction(selection);
      return;
    }
    if (choice.action == ConversationAction.settings) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            controller: widget.controller,
            preparingGoal: () => _preparingGoal,
          ),
        ),
      );
      return;
    }
    switch (choice.action) {
      case ConversationAction.search:
      case ConversationAction.settings:
        break;
      case ConversationAction.create:
        await _changeConversation();
      case ConversationAction.select:
        await _changeConversation(choice.id);
    }
  }

  Future<void> _changeConversation([String? id]) async {
    final controller = widget.controller;
    if (id == controller.activeConversation.id) {
      try {
        await controller.markActiveConversationRead();
      } on Object {
        if (mounted) _imageNotice('已读状态保存失败，请重试');
      }
      return;
    }
    if (_imageOperationPending()) return;
    if (_preparingGoal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在准备任务，请稍候')));
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
      if (id == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
      setState(() {});
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话保存失败，请稍后重试')));
      }
    }
  }

  void _useExample(String example) {
    _textController.text = example;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _focusNode.requestFocus();
  }

  bool _imageOperationPending() {
    if (!widget.controller.addingImages) return false;
    _imageNotice('正在处理图片，请稍候');
    return true;
  }

  Future<void> _addImages() async {
    final controller = widget.controller;
    if (controller.addingImages || controller.isBusy || _preparingGoal) return;
    if (controller.needsConfiguration) {
      _showModelConfigurationNotice();
      return;
    }
    if (controller.draftImages.length == MessageImageStore.maxImages) {
      _imageNotice('每条消息最多添加 4 张图片，请先移除一张');
      return;
    }
    _focusNode.unfocus();
    final source = await showImageSourceMenu(context);
    if (source != null && mounted) await _loadImages(source);
  }

  Future<void> _loadImages([ImageSource? source]) async {
    try {
      await widget.controller.addImages(source);
    } on Object catch (error) {
      if (!mounted) return;
      final permissionDenied =
          error is PlatformException &&
          {
            'camera_access_denied',
            'camera_access_denied_without_prompt',
            'camera_access_restricted',
            'photo_access_denied',
            'photo_access_denied_without_prompt',
            'photo_access_restricted',
          }.contains(error.code);
      _imageNotice(
        permissionDenied
            ? '请在系统设置中允许相机或照片访问'
            : switch (error) {
                ImageInputException() => error.message,
                PlatformException(code: 'no_available_camera') => '当前设备没有可用的相机',
                _ => '图片添加失败，请重新选择',
              },
        action: permissionDenied
            ? SnackBarAction(
                label: '去设置',
                onPressed: () async {
                  try {
                    await widget.controller.openAppSettings();
                  } on Object {
                    if (mounted) _imageNotice('无法打开设置，请在系统设置中找到 Aurai');
                  }
                },
              )
            : null,
      );
    }
  }

  Future<void> _removeImage(MessageImage image) async {
    try {
      await widget.controller.removeDraftImage(image);
    } on Object {
      if (mounted) _imageNotice('图片移除后保存失败，请重试');
    }
  }

  void _showModelConfigurationNotice() => _imageNotice(
    '请先连接模型',
    action: SnackBarAction(
      label: '模型设置',
      onPressed: () => _openSettings(continueAfterSave: false),
    ),
  );

  void _imageNotice(String message, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), action: action));

  Future<void> _send() async {
    if (_otherConversationRunning()) return;
    final conversationId = widget.controller.activeConversation.id;
    final goal = _textController.text.trim();
    if ((goal.isEmpty && widget.controller.draftImages.isEmpty) ||
        widget.controller.isBusy ||
        widget.controller.addingImages ||
        _preparingGoal) {
      return;
    }
    _preparingGoal = true;
    try {
      if (!await _ensureBackgroundRunReady()) return;
    } finally {
      _preparingGoal = false;
    }
    _draftTimer?.cancel();
    _focusNode.unfocus();
    _beforeSentMessageId = widget.controller.messages.lastOrNull?.id;
    _positionSentMessage = true;
    try {
      final needsSettings = await widget.controller.submitGoal(goal);
      if (needsSettings && mounted) {
        await _openSettings(continueAfterSave: true);
      }
    } on Object {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice();
    } finally {
      _positionSentMessage = false;
    }
  }

  Future<void> _continuePending() async {
    if (_otherConversationRunning()) return;
    final conversationId = widget.controller.activeConversation.id;
    if (_preparingGoal || widget.controller.addingImages) return;
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
    if (_imageOperationPending()) return;
    if (widget.controller.hasRunningTask) {
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

  bool _beforeDeleteConversation() {
    if (_imageOperationPending()) return false;
    if (widget.controller.isBusy || _preparingGoal) {
      _imageNotice('请先停止当前任务，再删除会话');
      return false;
    }
    _focusNode.unfocus();
    _draftTimer?.cancel();
    return true;
  }

  void _scrollToBottom() {
    _viewportKey.currentState?.scrollToBottom();
    if (!_followOutput) setState(() => _followOutput = true);
  }
}
