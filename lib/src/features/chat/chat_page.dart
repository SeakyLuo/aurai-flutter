import 'group_chat_page.dart';
import 'group_create_page.dart';
import '../../platform/message_file_store.dart';
import '../../scheduling/tasks_page.dart';
import 'keyboard_inset.dart';
import 'operation_request_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/message_image.dart';
import '../../platform/message_image_store.dart';
import 'image_attachments.dart';
import '../../domain/agent_models.dart';
import 'message_editor.dart';

import 'settings_page.dart';
import 'user_question_card.dart';
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

part 'chat_group_navigation.dart';
part 'chat_session_actions.dart';
part 'chat_message_editing.dart';
part 'chat_attachments.dart';
part 'chat_search_navigation.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    this.fromTask = false,
    this.originTaskId,
    this.initialMessageId,
  });

  final ChatController controller;
  final bool fromTask;
  final String? originTaskId;
  final String? initialMessageId;

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
  MessageEditSession? _editing;

  void _updateEditing(VoidCallback change) => setState(change);

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
      if (widget.initialMessageId case final id?) {
        _locateSearchMessage(id);
      } else {
        _scrollToBottom();
      }
      _loadImages();
    });
  }

  @override
  void dispose() {
    if (_editing != null) unawaited(_discardEditImages(_editing!));
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
      onEdit: _beginMessageEdit,
      beforeMessageId: _editing?.message.id,
      allowEditing: _editing == null,
    );
    final showProgress =
        (controller.isBusy && controller.runState != ChatRunState.idle) ||
        controller.pendingGoal != null ||
        controller.runState == ChatRunState.failed ||
        controller.runState == ChatRunState.cancelled ||
        controller.runState == ChatRunState.interrupted;
    if (_editing != null) {
      timeline.add(
        ChatTimelineEntry(
          _editing!.message.id,
          (_) => const MessageEditNotice(),
        ),
      );
    }
    if (showProgress && _editing == null) {
      timeline.add(
        ChatTimelineEntry(
          'progress:${controller.activeConversation.id}',
          (_) => _buildProgress(controller),
        ),
      );
    }
    return PopScope(
      canPop: _editing == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.fromTask) unawaited(_saveDraft());
        if (!didPop && _editing != null) _cancelMessageEdit();
      },
      child: AbsorbPointer(
        absorbing: controller.changingConversation,
        child: BackdropGroup(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: timeline.isEmpty ? Colors.transparent : null,
            drawer: widget.fromTask
                ? null
                : ConversationsDrawer(
                    controller: controller,
                    onChoose: _chooseConversationAction,
                  ),
            drawerEnableOpenDragGesture:
                !widget.fromTask &&
                _editing == null &&
                !controller.addingImages,
            onDrawerChanged: (opened) {
              if (opened) _focusNode.unfocus();
              if (!opened) _scheduleMarkRead();
            },
            extendBody: true,
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: false,
            appBar: ChatHeader(
              onMenu: _openConversations,
              onBack: widget.fromTask
                  ? () => Navigator.maybePop(context)
                  : null,
              editing: _editing != null,
              onCancelEdit:
                  (_editing?.saving == true || _editing?.picking == true)
                  ? null
                  : _cancelMessageEdit,
              controller: controller,
              beforeDelete: _beforeDeleteConversation,
              originTaskId: widget.originTaskId,
            ),
            bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
              child: KeyboardInset(
                child:
                    controller.pendingQuestion?.conversationId ==
                        _conversationId
                    ? UserQuestionCard(
                        key: ObjectKey(controller.pendingQuestion),
                        question: controller.pendingQuestion!,
                      )
                    : ChatComposer(
                        controller: _textController,
                        focusNode: _focusNode,
                        savingEdit: _editing?.saving == true,
                        draftEnabled: _editing != null
                            ? !_editing!.saving
                            : controller.canEditDraft && !_preparingGoal,
                        enabled: _editing != null
                            ? !_editing!.saving
                            : !controller.isBusy,
                        canSend:
                            _canSend ||
                            (_editing?.images ?? controller.draftImages)
                                .isNotEmpty ||
                            (_editing?.files ?? controller.draftFiles)
                                .isNotEmpty,
                        images: _editing?.images ?? controller.draftImages,
                        files: _editing?.files ?? controller.draftFiles,
                        onRemoveFile: (file) async {
                          if (_editing != null) {
                            _updateEditing(() => _editing!.files.remove(file));
                            return;
                          }
                          try {
                            await controller.removeDraftFile(file);
                          } on Object {
                            if (mounted) _imageNotice('附件移除失败，请重试');
                          }
                        },
                        addingImages:
                            controller.addingImages ||
                            _editing?.picking == true,
                        onAddImages: _editing != null
                            ? _addEditImages
                            : _addImages,
                        onRemoveImage: _editing != null
                            ? _removeEditImage
                            : _removeImage,
                        stopping: controller.runState == ChatRunState.stopping,
                        onSend: _editing != null ? _submitMessageEdit : _send,
                        canResume:
                            _editing == null &&
                            controller.runState == ChatRunState.cancelled &&
                            controller.pendingGoal != null,
                        onResume: _continuePending,
                        onStop: _stop,
                      ),
              ),
            ),
            body: DrawerDragRegion(
              enabled: !widget.fromTask,
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
                                  ? RepaintBoundary(
                                      child: EmptyConversation(
                                        contentPadding: EdgeInsets.only(
                                          top: top,
                                        ),
                                        onUseExample: _useExample,
                                      ),
                                    )
                                  : RepaintBoundary(
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
                                              _conversationId ==
                                                  conversationId) {
                                            setState(
                                              () => _contentBelow = value,
                                            );
                                          }
                                        },
                                        padding: EdgeInsets.only(
                                          top: top + 12,
                                          bottom: bottom + 16,
                                        ),
                                        hasEarlierMessages:
                                            controller.visibleHasEarlier,
                                        hasLaterMessages:
                                            controller.hasSearchWindow &&
                                            controller
                                                .activeConversation
                                                .searchHasLater,
                                        loadLaterMessages:
                                            controller.loadVisibleLaterMessages,
                                        loadEarlierMessages: controller
                                            .loadVisibleEarlierMessages,
                                        onBookmark: (bookmark) {
                                          if (_editing == null)
                                            _scrollBookmarks[conversationId] =
                                                bookmark;
                                        },
                                        onFollowOutputChanged: (value) {
                                          if (mounted)
                                            setState(
                                              () => _followOutput =
                                                  controller.hasSearchWindow
                                                  ? false
                                                  : value,
                                            );
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
                                (_contentBelow || controller.hasSearchWindow) &&
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
      ),
    );
  }

  Widget _buildProgress(ChatController controller) => ExecutionProgress(
    state: controller.runState,
    steps: controller.steps,
    errorDetail: controller.activeConversation.errorDetail,
    needsConfiguration: controller.needsConfiguration,
    hasPendingGoal: controller.pendingGoal != null,
    replying: controller.streamingMessageId != null,
    reconnectAttempt: controller.activeConversation.reconnectAttempt,
    onContinue: _continuePending,
    onRetry: _continuePending,
    accessibilityRequestPending: controller.accessibilityRequestPending,
    onBatterySettings: _openBatterySettings,
  );

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final requestedDraft = widget.controller.pendingComposerDraft;
    if (requestedDraft != null) {
      widget.controller.pendingComposerDraft = null;
      _textController.value = TextEditingValue(
        text: requestedDraft,
        selection: TextSelection.collapsed(offset: requestedDraft.length),
      );
    }
    final conversation = widget.controller.activeConversation;
    if (_conversationId != conversation.id) {
      final editing = _editing;
      _editing = null;
      if (editing != null) unawaited(_discardEditImages(editing));
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
    if (_editing == null &&
        widget.controller.isBusy &&
        conversation.draft.isEmpty &&
        _textController.text.isNotEmpty) {
      _textController.removeListener(_onTextChanged);
      _textController.clear();
      _textController.addListener(_onTextChanged);
      _canSend = false;
    } else if (_editing == null &&
        !widget.controller.isBusy &&
        conversation.draft != _textController.text) {
      _textController.removeListener(_onTextChanged);
      _textController.text = conversation.draft;
      _textController.addListener(_onTextChanged);
      _canSend = conversation.draft.trim().isNotEmpty;
    }
    setState(() {});
    if (!widget.fromTask &&
        widget.controller.accessibilityRequestPending &&
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
    if (!widget.fromTask &&
        confirmation != null &&
        confirmation != _shownConfirmation) {
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
    if (!identical(widget.controller.pendingConfirmation, request)) return;
    _focusNode.unfocus();
    final approved = await showOperationRequestSheet(
      context,
      controller: widget.controller,
      request: request,
      detail: detail,
    );
    if (identical(widget.controller.pendingConfirmation, request)) {
      widget.controller.resolveConfirmation(approved);
    }
    if (identical(_shownConfirmation, request)) _shownConfirmation = null;
  }

  String _intentSummary(Map<String, Object?> arguments) => <String>[
    'Action: ${arguments['action']}',
    if (arguments['data'] != null) 'Data: ${arguments['data']}',
    if (arguments['mimeType'] != null) 'Type: ${arguments['mimeType']}',
    if (arguments['packageName'] != null) 'App: ${arguments['packageName']}',
    if (arguments['extras'] != null) 'Extras: ${arguments['extras']}',
  ].join('\n');

  void _onTextChanged() {
    if (_editing != null) {
      final canSend = _textController.text.trim().isNotEmpty;
      if (_canSend != canSend) setState(() => _canSend = canSend);
      return;
    }
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

  Future<void> _chooseConversationAction(
    ConversationSelection selection,
  ) async {
    if (selection.action != ConversationAction.createGroup &&
        selection.action != ConversationAction.groups) {
      _scaffoldKey.currentState!.closeDrawer();
    }
    final choice = selection;
    if (choice.action == ConversationAction.groups ||
        choice.action == ConversationAction.createGroup) {
      await _openGroups(
        create: choice.action == ConversationAction.createGroup,
      );
      return;
    }
    if (choice.action == ConversationAction.tasks) {
      await openScheduledTasks(context, widget.controller);
      return;
    }
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
      final id = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            controller: widget.controller,
            preparingGoal: () => _preparingGoal,
          ),
        ),
      );
      if (mounted && id != null) {
        await _chooseConversationAction((
          action: ConversationAction.select,
          id: id,
          messageId: null,
        ));
      }
      return;
    }
    switch (choice.action) {
      case ConversationAction.groups:
      case ConversationAction.createGroup:
      case ConversationAction.tasks:
      case ConversationAction.search:
      case ConversationAction.settings:
        break;
      case ConversationAction.create:
        await _changeConversation();
      case ConversationAction.select:
        await _changeConversation(choice.id);
        if (mounted &&
            choice.messageId != null &&
            widget.controller.activeConversation.id == choice.id) {
          await _locateSearchMessage(choice.messageId!);
        }
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

  Future<void> _send() async {
    if (_otherConversationRunning()) return;
    final conversationId = widget.controller.activeConversation.id;
    final goal = _textController.text.trim();
    if ((goal.isEmpty &&
            widget.controller.draftImages.isEmpty &&
            widget.controller.draftFiles.isEmpty) ||
        widget.controller.isBusy ||
        widget.controller.addingImages ||
        _preparingGoal) {
      return;
    }
    _draftTimer?.cancel();
    _focusNode.unfocus();
    if (widget.controller.hasSearchWindow) _scrollToBottom();
    _beforeSentMessageId = widget.controller.messages.lastOrNull?.id;
    _positionSentMessage = true;
    try {
      final needsSettings = await widget.controller.submitGoal(goal);
      if (needsSettings && mounted) {
        _preparingGoal = true;
        await _openSettings(continueAfterSave: true);
      }
    } on Object {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice();
    } finally {
      _preparingGoal = false;
      _positionSentMessage = false;
    }
  }

  Future<void> _continuePending() async {
    if (_otherConversationRunning()) return;
    final conversationId = widget.controller.activeConversation.id;
    if (_preparingGoal || widget.controller.addingImages) return;
    if (widget.controller.needsConfiguration) {
      _preparingGoal = true;
      try {
        await _openSettings(continueAfterSave: true);
      } finally {
        _preparingGoal = false;
      }
      return;
    }
    try {
      await widget.controller.continuePending();
    } on Object {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice();
    }
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

  void _scrollToBottom() {
    widget.controller.cancelSearchNavigation();
    if (widget.controller.hasSearchWindow) {
      widget.controller.leaveSearchWindow();
      _scrollBookmarks.remove(_conversationId);
      setState(() {
        _viewportKey = GlobalKey<ChatViewportState>();
        _sentMessageId = null;
        _followOutput = true;
      });
      return;
    }
    _viewportKey.currentState?.scrollToBottom();
    if (!_followOutput) setState(() => _followOutput = true);
  }

  void _positionSearchResult(String id) =>
      setState(() => _applySearchPosition(id));
}
