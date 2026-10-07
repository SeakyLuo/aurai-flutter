import 'app_bottom_sheet.dart';
import 'profile_navigation.dart';
import 'pinned_message_split.dart';
import 'draft_visibility_sheet.dart';
import 'send_options_sheet.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import '../../storage/group_participation.dart';
import '../../app/ui_action.dart';
import 'group_announcement_banner.dart';
import 'group_mute_builder.dart';
import 'send_favorite_page.dart';
import 'send_miniapp_message.dart';
import 'asset_library_page.dart';
import '../../domain/library_asset.dart';
import 'workspace_changes_panel.dart';
import 'pending_message_panel.dart';
import 'message_jump_arrow.dart';
import '../../app/global_ui.dart';
import 'glass_surface.dart';
import '../../app/glass_notice.dart';
import 'group_status_builder.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import 'home_page.dart';
import '../../domain/message_sender.dart';
import 'run_timeline_sheet.dart';
import '../../domain/error_message.dart';
import '../../domain/draft_mention.dart';
import 'mention_text_controller.dart';
import 'group_mention_sheet.dart';
import 'group_activity_avatars.dart';
import 'group_activity_sheet.dart';
import '../../platform/message_file_store.dart';
import 'keyboard_inset.dart';
import 'dart:async';
import '../../agent/ask_user_tool.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/message_image.dart';
import '../../platform/message_image_store.dart';
import 'image_attachments.dart';
import '../../domain/agent_models.dart';
import 'message_editor.dart';

import 'user_question_card.dart';
import 'user_question_scope.dart';
import 'search_aurora_background.dart';
import 'accessibility_request_sheet.dart';
import 'chat_controller.dart';
import 'chat_widgets.dart';
import 'quote_focus_view.dart';
import 'chat_empty_state.dart';
import 'chat_header.dart';
import 'thinking_indicator.dart';
import 'chat_viewport.dart';
import 'message_item.dart';
import 'jump_to_bottom_button.dart';
import 'chat_timeline.dart';
import 'model_settings_sheet.dart';

part 'chat_pinned_message.dart';
part 'chat_body.dart';
part 'chat_group_navigation.dart';
part 'chat_mentions.dart';
part 'chat_progress.dart';
part 'chat_session_actions.dart';
part 'chat_message_editing.dart';
part 'chat_attachments.dart';
part 'chat_search_navigation.dart';
part 'chat_quoting.dart';
part 'chat_message_submission.dart';
part 'chat_composer.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    this.fromTask = false,
    this.stacked = false,
    this.originTaskId,
    this.initialMessageId,
    this.initialText,
  });

  final ChatController controller;
  final bool fromTask;
  final bool stacked;
  final String? originTaskId;
  final String? initialMessageId;
  final String? initialText;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with WidgetsBindingObserver, RouteAware {
  static final _chatPages = <_ChatPageState>{};
  List<DraftMention> get _mentions =>
      widget.controller.activeConversation.draftMentions;
  late String _mentionText = widget.controller.activeConversation.draft;
  late String _mentionConversationId = widget.controller.activeConversation.id;
  bool _mentionOpen = false;
  final _draftVisibility = <String, DraftVisibility>{};
  final _pinSplitKey = GlobalKey<PinnedMessageSplitState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final _textController = MentionTextController(
    () => _mentions,
    onOpenMention: _openDraftMention,
  );
  final _focusNode = FocusNode();
  var _viewportKey = GlobalKey<ChatViewportState>();
  final _scrollBookmarks = <String, ChatScrollBookmark>{};
  ChatScrollBookmark? _quoteBookmark;
  QuoteFocusVisual? _quoteVisual;
  final _quoteFocusKey = GlobalKey<QuoteFocusMessageState>();
  final _quoteComposerKey = GlobalKey();
  bool _quoteReturning = false;
  var _canSend = false;
  var _followOutput = true;
  bool _contentBelow = false;
  bool _positionSentMessage = false;
  String? _beforeSentMessageId;
  String? _sentMessageId;
  late String _conversationId;
  Timer? _draftTimer;
  bool _preparingGoal = false;
  bool _accessibilitySheetShowing = false;
  bool _markReadScheduled = false;
  bool _locatingInitialMessage = true;
  final _unreadTarget = ValueNotifier<_UnreadTarget?>(null);
  bool _jumpingToUnread = false;
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _temporaryExitPending = false;
  bool _temporaryExitReady = false;
  ToastHandle? _runNotice;
  MessageEditSession? _editing;
  UserQuestion? _shownQuestion;
  bool _questionSheetShowing = false;
  bool _questionSheetScheduled = false;

  void _updateEditing(VoidCallback change) => setState(change);
  void _updateChatBody(VoidCallback change) => setState(change);
  void _updateDraftVisibility(VoidCallback change) => setState(change);
  void _clearMessageHighlight() => setState(() => _highlightedMessageId = null);
  @override
  void initState() {
    super.initState();
    widget.controller.programErrors.addListener(_onProgramError);
    _conversationId = widget.controller.activeConversation.id;
    _textController.text = widget.controller.activeConversation.draft;
    _canSend = _textController.text.trim().isNotEmpty;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_locateInitialMessage());
      _loadImages();
      _focusNewConversation();
      if (widget.initialText case final text?) {
        _textController.text = text;
        unawaited(_send());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatPages.add(this);
    homeRouteObserver.subscribe(
      this,
      ModalRoute.of(context)! as PageRoute<dynamic>,
    );
  }

  void _recordPagePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final visible = _chatPages.any(
        (page) =>
            page.mounted &&
            identical(page.widget.controller, widget.controller) &&
            ModalRoute.of(page.context)!.isCurrent,
      );
      unawaited(
        widget.controller.setConversationDetailVisible(visible).catchError((
          Object error,
        ) {
          if (mounted)
            ScaffoldMessenger.of(context).showToast(
              SnackBar(content: Text(errorMessage(error))),
              kind: ToastKind.error,
            );
        }),
      );
    });
  }

  @override
  void didPush() => _recordPagePosition();
  @override
  void didPopNext() {
    _recordPagePosition();
    setState(() {});
  }

  @override
  void didPushNext() {
    if (!_questionSheetShowing) _shownQuestion = null;
    _runNotice?.close();
    _runNotice = null;
    _recordPagePosition();
  }

  @override
  void didPop() {
    _runNotice?.close();
    _runNotice = null;
    _recordPagePosition();
  }

  @override
  void dispose() {
    widget.controller.programErrors.removeListener(_onProgramError);
    homeRouteObserver.unsubscribe(this);
    _chatPages.remove(this);
    _recordPagePosition();
    if (_editing != null) unawaited(_discardEditImages(_editing!));
    _draftTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _unreadTarget.dispose();
    _highlightTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onProgramError() {
    final error = widget.controller.programErrors.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(error)), kind: ToastKind.error);
    }
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
    final active = controller.activeConversation;
    final conversationId = active.id;
    final isGroup = active.kind == ConversationKind.group;
    final pendingQuestion =
        controller.pendingQuestion?.conversationId == conversationId
        ? controller.pendingQuestion
        : null;
    if (pendingQuestion != null &&
        !identical(_shownQuestion, pendingQuestion) &&
        !_questionSheetShowing &&
        !_questionSheetScheduled &&
        ModalRoute.of(context)!.isCurrent) {
      _questionSheetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _questionSheetScheduled = false;
        if (!mounted ||
            !identical(controller.pendingQuestion, pendingQuestion) ||
            !ModalRoute.of(context)!.isCurrent)
          return;
        _shownQuestion = pendingQuestion;
        _focusNode.unfocus();
        setState(() => _questionSheetShowing = true);
        try {
          if (pendingQuestion.messageId case final id?) {
            await _locateSearchMessage(id);
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted || controller.activeConversation.id != conversationId)
              return;
          }
          await showUserQuestionSheet(
            context,
            question: pendingQuestion,
            showSender: isGroup,
            onOpenSender: () => openProfileRoute(
              _scaffoldKey.currentContext!,
              MaterialPageRoute(
                builder: (_) => AiContactPage(
                  controller: controller,
                  senderId: pendingQuestion.sender.id,
                  groupId: isGroup ? pendingQuestion.conversationId : null,
                ),
              ),
            ),
          );
        } finally {
          if (mounted) setState(() => _questionSheetShowing = false);
        }
      });
    }
    final timeline = buildChatTimeline(
      controller,
      onEdit: _beginMessageEdit,
      onRecall: _recallMessage,
      onReeditRecalled: _reeditRecalledMessage,
      onQuote: _editing == null ? _quoteMessage : null,
      onMention: controller.canEditDraft && _editing == null
          ? _mentionMember
          : null,
      onOpenQuote: _openQuotedMessage,
      onQuickReply: _sendQuickReply,
      onRetry: _retryFailedMessage,
      beforeMessageId: _editing?.message.id,
      highlightedMessageId: _highlightedMessageId,
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
    if (active.isTask && showProgress && _editing == null) {
      timeline.add(
        ChatTimelineEntry(
          'progress:${controller.activeConversation.id}',
          (_) => _buildProgress(controller),
        ),
      );
    }
    final showWelcome =
        timeline.isEmpty &&
        active.isTask &&
        !active.isTemporary &&
        controller.conversations.isEmpty;
    return UserQuestionScope(
      question: pendingQuestion,
      onOpen: () => setState(() => _shownQuestion = null),
      child: PopScope(
        canPop:
            !_quoteFocused &&
            _editing == null &&
            (!active.isTemporary || _temporaryExitReady),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) unawaited(_saveDraft());
          if (!didPop && _editing != null) {
            _cancelMessageEdit();
          } else if (!didPop && _quoteFocused) {
            unawaited(_quoteMessage(null));
          } else if (!didPop && active.isTemporary) {
            unawaited(_exitTemporaryConversation());
          }
        },
        child: AbsorbPointer(
          absorbing: controller.changingConversation,
          child: BackdropGroup(
            child: PinnedMessageSplit(
              key: _pinSplitKey,
              controller: controller,
              conversationId: conversationId,
              onLocate: _locateSearchMessage,
              messageBuilder: _buildPinnedMessage,
              child: Scaffold(
                key: _scaffoldKey,
                backgroundColor: showWelcome ? Colors.transparent : null,
                extendBody: true,
                extendBodyBehindAppBar: true,
                resizeToAvoidBottomInset: false,
                appBar: ChatHeader(
                  onBack: () =>
                      _pinSplitKey.currentState!.backFromConversation(),
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
                    enabled: !_questionSheetShowing,
                    child: WorkspaceChangesPanel(
                      controller: controller,
                      child: PendingMessagePanel(
                        controller: controller,
                        onSend: _sendQueuedMessages,
                        onEdit: _editing == null && !controller.addingImages
                            ? _editQueuedMessage
                            : null,
                        child: _buildQuoteComposer(isGroup),
                      ),
                    ),
                  ),
                ),
                body: _buildChatBody(context, timeline, showWelcome, isGroup),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onControllerChanged() {
    if (mounted &&
        !ModalRoute.of(context)!.isCurrent &&
        _conversationId != widget.controller.activeConversation.id)
      return;
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
    _syncQuotePosition();
    if (_conversationId != conversation.id) {
      _shownQuestion = null;
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
      _mentions.clear();
      _mentionText = '';
      _textController.addListener(_onTextChanged);
      _canSend = false;
    } else if (_editing == null &&
        !widget.controller.isBusy &&
        conversation.draft != _textController.text) {
      _textController.removeListener(_onTextChanged);
      _mentionText = conversation.draft;
      _textController.text = conversation.draft;
      _textController.addListener(_onTextChanged);
      _canSend = conversation.draft.trim().isNotEmpty;
    }
    setState(() {});
    _scheduleMarkRead();
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
  }

  void _onTextChanged() {
    _trackMentions();
    if (_editing != null) {
      final canSend = _textController.text.trim().isNotEmpty;
      if (_canSend != canSend) setState(() => _canSend = canSend);
      return;
    }
    widget.controller.updateDraft(_textController.text);
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
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('草稿保存失败，请稍后重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _continuePending() async {
    final conversationId = widget.controller.activeConversation.id;
    if (_preparingGoal || widget.controller.addingImages) return;
    if (widget.controller.needsReplyConfiguration) {
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
    } on Object catch (error) {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice(error);
    }
  }

  Future<void> _stop() => widget.controller.stop();

  Future<void> _openSettings({required bool continueAfterSave}) async {
    if (_imageOperationPending()) return;
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
    _viewportKey.currentState?.scrollToBottom(interrupt: true);
    if (!_followOutput) setState(() => _followOutput = true);
  }

  void _positionSearchResult(String id) =>
      setState(() => _applySearchPosition(id));
}
