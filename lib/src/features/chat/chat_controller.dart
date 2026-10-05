import '../../storage/home_conversations.dart';
import '../../domain/tool_detail_target.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../../agent/private_task_tool.dart';
import '../../storage/private_task_state.dart';
import '../../storage/asset_library.dart';
import '../../domain/library_asset.dart';
import '../../storage/project_directory.dart';
import '../../platform/project_run_snapshots.dart';
import '../../agent/group_notice_tool.dart';
import '../../agent/group_access_tool.dart';
import '../../agent/peer_access_tool.dart';
import '../../agent/deliver_file_tool.dart';
import '../../platform/generated_file_store.dart';
import '../../agent/group_message_marks_tool.dart';
import '../../storage/group_message_marks.dart';
import '../../domain/request_adapter.dart';
import '../../domain/context_summary.dart';
import '../../domain/live_project_changes.dart';
import '../../providers/request_adapter_runner.dart';
import '../../providers/responses_transport.dart';
import '../../providers/response_message_input.dart';
import '../../providers/model_image_input.dart';
import '../../agent/request_adapter_tool.dart';
import 'pending_message_queue.dart';
import '../../domain/quick_reply_option.dart';
import '../../agent/provider_configuration_tool.dart';
import 'provider_icon_store.dart';
import '../../providers/model_catalog.dart';
import '../../providers/provider_connection_check.dart';
import '../../agent/user_data_read_tool.dart';
import '../../app/language_settings.dart';
import '../../agent/hide_thinking_tool.dart';
import '../../agent/group_wake_tool.dart';
import '../../agent/group_auto_reply_tool.dart';
import '../../agent/group_mute_tool.dart';
import '../../storage/group_system_notice.dart';
import '../../platform/svg_image.dart';
import '../../domain/image_generation_config.dart';
import '../../providers/image_generation_client.dart';
import '../../providers/music_generation_client.dart';
import '../../agent/image_generation_tool.dart';
import '../../agent/music_generation_tool.dart';
import '../../providers/openrouter_models.dart';
import '../../providers/model_purpose_catalog.dart';
import '../../storage/draft_attachment_cleanup.dart';
import '../../storage/quick_reply_recents.dart';
import '../../agent/quick_reply_tool.dart';
import '../../agent/starred_message_tool.dart';
import '../../agent/html_app_data_tool.dart';
import '../../agent/html_app_publication_tool.dart';
import '../../html_games/miniapp_library_store.dart';
import '../../html_games/miniapp_agent_catalog.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/miniapp_template.dart';
import '../../html_games/html_app_store.dart';
import '../../html_games/html_app_edit.dart';
import '../../agent/html_app_edit_tool.dart';
import '../../storage/interactive_callback_result.dart';
import '../../storage/interactive_callback_state.dart';
import '../../storage/conversation_navigation_state.dart';
import '../../domain/tool_customization.dart';
import '../../storage/interactive_action_history.dart';
import '../../storage/group_unread_messages.dart';
import '../../storage/recalled_message_drafts.dart';
import '../../html_games/html_message_interaction.dart';
import '../../storage/message_callbacks.dart';
import '../../agent/html_message_update_tool.dart';
import '../../agent/html_data_access_tool.dart';
import '../../html_games/html_message_data.dart';
import 'notification_avatar.dart';
import '../../agent/friend_tools.dart';
import '../../storage/contact_relationships.dart';
import '../../domain/error_message.dart';
import '../../domain/message_lookup_error.dart';
import '../../agent/execution_log_tool.dart';
import '../../diagnostics/execution_log.dart';
import '../../agent/html_message_tool.dart';
import '../../html_games/html_store.dart';
import '../../html_games/html_game_session.dart';
import '../../html_games/miniapp_program_store.dart';
import '../../html_games/miniapp_group_message_router.dart';
import '../../domain/interactive_message.dart';
import '../../domain/interactive_tool_view.dart';
import '../../storage/interactive_completion.dart';
import '../../storage/interactive_message_store.dart';
import '../../agent/interactive_message_tool.dart';
import '../../agent/history_message_tools.dart';
import '../../storage/group_sleep_store.dart';
import '../../agent/group_history_tool.dart';
import 'markdown_preview_text.dart';
import '../../domain/markdown_plain_text.dart';
import 'dart:developer' as developer;
import '../../agent/app_control_tool.dart';
import '../../agent/app_assistance_tool.dart';
import '../../agent/recall_message_tool.dart';
import '../../agent/self_profile_tool.dart';
import 'avatar_symbol.dart';
import 'avatar_background.dart';
import '../../storage/conversation_visibility.dart';
import '../../domain/message_quote.dart';
import '../../agent/group_message_tool.dart';
import '../../agent/group_sleep_tool.dart';
import '../../storage/group_participation.dart';
import 'group_dispatcher.dart';
import '../../agent/group_chat_tools.dart';
import '../../agent/project_tools.dart';
import '../../agent/group_announcement_tool.dart';
import '../../storage/group_announcement_store.dart';
import '../../agent/ai_contact_tools.dart';
import '../../platform/ai_document_scope.dart';
import '../../storage/attachment_search.dart';
import '../../storage/group_chat_store.dart';
import '../../storage/protocol_history.dart';
import '../../storage/conversation_tool_history.dart';
import '../../agent/attachment_tool.dart';
import 'tool_approval_store.dart';
import '../../domain/message_file.dart';
import '../../platform/message_file_store.dart';
import '../../platform/document_tools.dart';
import '../../platform/project_development_tools.dart';
import '../../platform/git_configuration_tool.dart';
import '../../platform/wait_for_ui_tool.dart';
import '../../platform/device_extension_tools.dart';
import '../../agent/image_search_tool.dart';
import '../../skills/skill_store.dart';
import '../../skills/skill_tools.dart';
import 'dart:async';
import '../../domain/ui_tool_actions.dart';
import '../../scheduling/scheduled_tasks.dart';
import '../../scheduling/schedule_tool.dart';
import 'dart:convert';
import 'dart:io';
import '../../memory/memory_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../agent/agent_runtime.dart';
import '../../agent/response_decision.dart';
import '../../agent/system_prompt.dart';
import '../../agent/ask_user_tool.dart';
import '../../agent/model_balance_tool.dart';
import '../../agent/default_model_tools.dart';
import '../../agent/memory_tools.dart';
import '../../agent/model_top_up_tool.dart';
import '../../agent/group_tool_executor.dart';
import '../../agent/tool_registry.dart';
import '../../agent/local_history_tools.dart';
import '../../agent/web_tools.dart';
import '../../agent/source_dates_tool.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../domain/message_quick_reply.dart';
import '../../domain/ai_profile.dart';
import '../../domain/conversation_completion.dart';
import '../../domain/capability.dart';
import '../../domain/model_provider.dart';
import '../../domain/music_model_selection.dart';
import '../../domain/tool_models.dart';
import '../../platform/android_network_tools.dart';
import '../../platform/android_agent_tools.dart';
import '../../platform/android_notification_tools.dart';
import '../../platform/send_notification_tool.dart';
import '../../platform/android_runtime_tools.dart';
import '../../platform/aurai_platform.dart';
import '../../platform/message_image_store.dart';
import '../../domain/message_image.dart';
import '../../providers/deepseek_responses_provider.dart';
import '../../providers/openai_responses_provider.dart';
import 'conversation.dart';
import '../../storage/conversation_store.dart';
import '../../storage/conversation_message_edit.dart';
import '../../storage/new_conversation_draft.dart';
import '../../storage/conversation_reader.dart';
import '../../storage/conversation_rows.dart';
import '../../storage/development_projects.dart';

export 'conversation.dart';

part 'message_quote_actions.dart';
part 'pending_message_submission.dart';
part 'message_recall.dart';
part 'message_submission.dart';
part 'message_quick_replies.dart';
part 'global_tools.dart';
part 'generated_file_actions.dart';
part 'conversation_branching.dart';
part 'group_reply_context.dart';
part 'group_reply_draft.dart';
part 'ai_identity_controller.dart';
part 'project_controller_actions.dart';
part 'group_conversation_run.dart';
part 'group_member_activity.dart';
part 'group_message_delivery.dart';
part 'group_message_audience.dart';
part 'private_group_message.dart';
part 'group_private_conversation.dart';
part 'group_system_events.dart';
part 'conversation_actions.dart';
part 'app_control_actions.dart';
part 'app_assistance_actions.dart';
part 'peer_conversations.dart';
part 'interactive_message_actions.dart';
part 'interactive_ai_decision.dart';
part 'message_callback_actions.dart';
part 'html_actions.dart';
part 'miniapp_template_sending.dart';
part 'model_config_actions.dart';
part 'request_adapter_actions.dart';
part 'provider_configuration_actions.dart';
part 'image_generation_actions.dart';
part 'music_generation_actions.dart';
part 'image_forwarding.dart';
part 'draft_attachment_actions.dart';
part 'asset_library_actions.dart';
part 'conversation_search_navigation.dart';
part 'conversation_run.dart';
part 'run_tool_logging.dart';
part 'conversation_run_failure.dart';
part 'conversation_run_continuation.dart';
part 'conversation_run_persistence.dart';
part 'scheduled_execution.dart';
part 'message_edit_actions.dart';
part 'accessibility_request.dart';
part 'pending_confirmation.dart';
part 'private_goal_actions.dart';
part 'conversation_execution_state.dart';
part 'live_project_changes.dart';
part 'group_sleep_recovery.dart';
part 'group_run_tools.dart';
part 'group_member_mute.dart';
part 'user_data_read_access.dart';
part 'group_tool_access.dart';

class ChatController extends ChangeNotifier {
  AiProfile? _activeAi;
  AiProfile? get activeAi => _activeAi;
  bool hasRestoredConversation = false;
  final navigationState = ConversationNavigationState();
  bool isConversationDetailVisible = false;
  Future<void> setConversationDetailVisible(bool visible) async {
    if (isConversationDetailVisible == visible &&
        navigationState.detailVisible == visible)
      return;
    isConversationDetailVisible = visible;
    _conversationChanged();
    await navigationState.setDetailVisible(visible);
  }

  bool startsWithoutConversations = false;
  final Map<String, MemoryController> _aiMemories = {};
  final Map<String, SkillStore> _aiSkills = {};
  ChatController(this._platform);

  final AuraiPlatform _platform;
  final scheduledTasks = ScheduledTasks();
  final _groupSleeps = GroupSleepStore();
  final skills = SkillStore();
  final toolApprovals = ToolApprovalStore();
  String? pendingComposerDraft;

  Future<void> prepareSkillCreation() async {
    await createConversation();
    final draft = activeConversation.draft;
    updateDraft("${draft.isEmpty ? '' : '$draft\n\n'}帮我创建一个可复用的技能：");
    await saveDraft();
    pendingComposerDraft = activeConversation.draft;
    notifyListeners();
  }

  bool _claimingSchedule = false;
  final _imageStore = MessageImageStore();
  bool get addingImages => _execution.attachmentJobs > 0;
  Future<void> _forwardingTail = Future<void>.value();
  List<MessageImage> get draftImages => activeConversation.draftImages;
  List<MessageFile> get draftFiles => activeConversation.draftFiles;
  Future<void> Function(Map<String, Object?>)? openAppPage;
  Future<void> _modelSettingsWrite = Future<void>.value();
  final notificationOpenRequests = ValueNotifier<int>(0);
  Future<String?> takeNotificationConversation() =>
      _platform.takeNotificationConversation();
  final questionNotifications = ValueNotifier<ConversationCompletion?>(null);
  final completedReplies = ValueNotifier<ConversationCompletion?>(null);
  final _store = ConversationStore();
  StreamSubscription<void>? _callbackChanges;
  StreamSubscription<MiniappProgramChange>? _programChanges;
  Timer? _programTimer;
  int _programScheduleGeneration = 0;
  StreamSubscription<List<CallbackCardUpdate>>? _callbackCardChanges;
  bool _drainingCallbacks = false;
  final _callbackConversations = <String>{};
  bool _callbacksDisposed = false;
  bool _callbacksPending = true;
  Timer? _callbackMuteExpiry;
  int _callbackGeneration = 0;
  MemoryController? _memory;
  MemoryController get memory => _memory!;
  String _lastLocalName = MessageSender.localUser.name;
  final _newDraftStore = NewConversationDraft();
  late Conversation _newConversation;
  final List<Conversation> _conversations = [];
  late Conversation _viewConversation;
  final _pendingMessageQueues = <String, PendingMessageQueue>{};
  final _executionStates = <String, _ConversationExecutionState>{};
  final _uiZone = Zone.current;
  var _viewExecution = _ConversationExecutionState();
  Conversation get _activeConversation => _viewConversation;
  set _activeConversation(Conversation value) {
    _executionStates.removeWhere(
      (id, state) =>
          id != value.id &&
          state.leases == 0 &&
          state.runningConversation == null &&
          !state.submitting,
    );
    _viewConversation = value;
    _viewExecution = _executionStates.putIfAbsent(
      value.id,
      _ConversationExecutionState.new,
    )..conversation = value;
  }

  Conversation get activeConversation =>
      (Zone.current[_executionZoneKey] as _ConversationExecutionState?)
          ?.conversation ??
      _viewConversation;

  @override
  void notifyListeners() => _uiZone.run(super.notifyListeners);
  Conversation? _conversationCursor;
  bool hasMoreConversations = false;
  bool loadingConversations = false;
  bool loadingEarlierMessages = false;
  bool changingConversation = false;
  bool creatingConversationBranch = false;
  ResponsesTransport? _conversationBranchTransport;
  List<Conversation> get conversations => List.unmodifiable(
    <Conversation>[..._conversations.where((item) => !item.isArchived)]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.listUpdatedAt.compareTo(a.listUpdatedAt);
      }),
  );
  List<AgentMessage> get messages => activeConversation.messages;
  List<AgentStep> get steps => activeConversation.steps;
  final List<Capability> capabilities = <Capability>[];
  ModelSettings modelSettings = ModelSettings.defaults();
  ImageGenerationConfig? imageGeneration;
  ChatRunState get runState => activeConversation.runState;
  set runState(ChatRunState value) => activeConversation.runState = value;
  String? get pendingGoal => activeConversation.pendingGoal;
  set pendingGoal(String? value) => activeConversation.pendingGoal = value;
  String? get errorDetail => activeConversation.errorDetail;
  set errorDetail(String? value) => activeConversation.errorDetail = value;
  final _recallingMessages = <String>{};
  final _queuedSystemNotices = <String, List<AgentMessage>>{};
  bool _systemEventDrainScheduled = false;
  final _groupToolQueue = GroupToolQueue();
  final groupActivityChanges = ValueNotifier<int>(0);
  final contactsChanged = ValueNotifier<AiProfile?>(null);
  final programErrors = ValueNotifier<String?>(null);
  final _peerSessions = <String, Future<_PeerSession>>{};
  Iterable<Conversation> get groupRuns =>
      activeConversation.id == runningConversationId
      ? _groupRuns.values
      : const [];
  bool isStreamingMessage(String id) =>
      streamingMessageId == id || _groupStreaming.containsValue(id);
  bool get hasStreamingMessages =>
      streamingMessageId != null || _groupStreaming.isNotEmpty;
  bool get hasRunningTask =>
      pendingMessageQueue.busy ||
      _systemEventLoading ||
      _runningConversation != null ||
      _privateConversation != null ||
      _submitting;
  String? get runningConversationId => _runningConversation?.id;

  VoidCallback? _detachGroupNotices;

  void _accessibilityChanged() => notifyListeners();

  @override
  void dispose() {
    _disposeExecutions();
    _stopPeerSessions();
    _queuedSystemNotices.clear();
    _detachGroupNotices?.call();
    skills.dispose();
    for (final store in _aiMemories.values) {
      store.dispose();
    }
    for (final store in _aiSkills.values) {
      store.dispose();
    }
    scheduledTasks.dispose();
    _groupSleeps.dispose();
    _callbacksDisposed = true;
    _callbackChanges?.cancel();
    _programChanges?.cancel();
    _programTimer?.cancel();
    _callbackCardChanges?.cancel();
    removeListener(_drainMessageCallbacks);
    _memory?.removeListener(_onLocalProfileChanged);
    _memory?.dispose();
    _accessibilityTimer?.cancel();
    completedReplies.dispose();
    questionNotifications.dispose();
    notificationOpenRequests.dispose();
    groupActivityChanges.dispose();
    contactsChanged.dispose();
    programErrors.dispose();
    super.dispose();
  }

  bool get isSubmitting => _submitting;

  bool get isBusy =>
      _submitting ||
      creatingConversationBranch ||
      identical(_runningConversation, activeConversation) ||
      identical(_privateConversation, activeConversation) ||
      runState == ChatRunState.running ||
      runState == ChatRunState.stopping;

  bool get canSendToRunningGroup =>
      !_submitting &&
      _groupDispatcher != null &&
      !_groupDispatcher!.closed &&
      identical(_runningConversation, activeConversation) &&
      runState == ChatRunState.running;

  bool get canEditDraft =>
      !_submitting && !changingConversation && !pendingMessageQueue.busy;

  ModelConfig get config =>
      _activeAi == null ? modelSettings.activeConfig : aiConfig(_activeAi!);

  bool get needsConfiguration => !config.isConfigured;

  bool get needsReplyConfiguration =>
      activeConversation.kind == ConversationKind.direct && needsConfiguration;

  bool get hasCapabilityIssue => capabilities.any(
    (capability) =>
        capability.availability == CapabilityAvailability.permissionRequired,
  );

  Future<void> initialize() async {
    _platform.setStopHandler(
      _stopNotificationConversation,
      () => notificationOpenRequests.value++,
    );
    await _imageStore.initialize();
    await toolApprovals.initialize();
    await navigationState.initialize();
    await OpenRouterModels.initialize();
    await DetectedModelPurposes.initialize();
    await refreshCapabilities();
    final activeId = await _store.initialize(
      _imageStore.directory,
      _platform.loadLegacyAppState,
      _platform.clearLegacyAppState,
    );
    modelSettings = await _platform.loadModelSettings();
    await ToolCustomizations.initialize(_store.database);
    await _loadPendingMessageQueues();
    await _loadImageGeneration();
    await _migrateMusicGeneration();
    groupStore.onSystemNotice = _receiveGroupSystemNotice;
    _detachGroupNotices = () => groupStore.onSystemNotice = null;
    _platform.notificationAvatar = NotificationAvatar(groupStore).render;
    _memory = MemoryController(_store.database, () => config);
    await memory.initialize();
    _lastLocalName = memory.nickname.isEmpty
        ? MessageSender.localUser.name
        : memory.nickname;
    memory.addListener(_onLocalProfileChanged);
    await _migrateAiSettings();
    await skills.initialize(_store.database);
    _newConversation = await _newDraftStore.load(_imageStore.directory);
    if (await _store.hasConversation(_newConversation.id)) {
      await _newDraftStore.clear();
      _newConversation = Conversation.empty();
    }
    _activeConversation = activeId == null
        ? _newConversation
        : await _store.load(activeId);
    await _storeNewDraft();
    hasRestoredConversation = activeId != null || activeConversation.isStored;
    startsWithoutConversations = (await _store.database.query(
      'conversations',
      columns: ['id'],
      limit: 1,
    )).isEmpty;
    _activeAi = activeConversation.kind == ConversationKind.direct
        ? await groupStore.loadAi(activeConversation.defaultSenderId)
        : null;
    await _reloadConversations();
    await DraftAttachmentCleanup(
      _store.database,
      _imageStore.directory,
    ).recover();
    _callbackCardChanges = MessageCallbacks.cardChanges.stream.listen((
      updates,
    ) {
      for (final update in updates) {
        _replaceInteractiveCard(
          update.conversationId,
          update.messageId,
          update.card,
        );
      }
    });
    await MessageCallbacks(_store.database).recoverInterrupted();
    await scheduledTasks.initialize(_runScheduled);
    await _groupSleeps.initialize(_store.database, _recoverGroupSleep);
    _programChanges = MiniappProgramStore.changes.stream.listen(
      _receiveProgramChange,
    );
    _scheduleProgramTick();
    _callbackChanges = MessageCallbacks.changes.stream.listen((_) {
      _callbacksPending = true;
      _callbackGeneration++;
      _drainMessageCallbacks();
    });
    addListener(_drainMessageCallbacks);
    _drainMessageCallbacks();
    notifyListeners();
  }

  Future<void> continuePending() =>
      _inConversation(activeConversation, _continuePending);

  Future<void> _continuePending() async {
    if (canStartPrivateDuringGroup) {
      await _runPrivateDuringGroup();
      return;
    }
    if (hasRunningTask) return;
    if (pendingGoal == null) return;
    final conversation = activeConversation;
    _runningConversation = conversation;
    notifyListeners();
    try {
      await _executeConversation(conversation);
    } finally {
      _runningConversation = null;
      _resumeForwardedReply();
      _drainGroupSystemNotices();
      _updateConversationList(conversation);
      notifyListeners();
    }
  }

  Future<void> refreshCapabilities() async {
    final loaded = await _platform.loadCapabilities();
    capabilities
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<Map<String, Object?>> getBackgroundRunReadiness() =>
      _platform.getBackgroundRunReadiness();

  Future<bool> requestNotificationPermission() =>
      _platform.requestNotificationPermission();

  Future<void> openAppSettings() async {
    await _platform.openSettings('appDetails');
  }

  Future<void> openNotificationSettings() =>
      _platform.openNotificationSettings();

  Future<void> openNotificationAccessSettings() async {
    await _platform.openSettings('notificationAccess');
  }

  Future<void> openAccessibilitySettings() =>
      _platform.openAccessibilitySettings();

  Future<void> openBatterySettings() => _platform.openBatterySettings();

  void resolveConfirmation(bool approved) {
    final request = pendingConfirmation;
    if (request == null) return;
    request.completer.complete(approved);
    pendingConfirmation = null;
    notifyListeners();
  }

  final _loadedMessageCounts = <String, int>{};
  Conversation? _pendingAiConversation;
  final _searchWindows = <String, Conversation>{};
  int _searchNavigationGeneration = 0;

  void _conversationChanged() => notifyListeners();

  Future<void> refreshConversations() async {
    if (loadingConversations) return;
    loadingConversations = true;
    try {
      await _reloadConversations();
      if (activeConversation.kind == ConversationKind.group) {
        await refreshGroupDisplayNames(activeConversation.id);
      }
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreConversations() async {
    if (loadingConversations || !hasMoreConversations) return;
    loadingConversations = true;
    try {
      final page = await _store.reader.list(after: _conversationCursor);
      final ids = _conversations.map((item) => item.id).toSet();
      _conversations.addAll(page.where((item) => !ids.contains(item.id)));
      if (page.isNotEmpty) _conversationCursor = page.last;
      hasMoreConversations = page.length == ConversationReader.pageSize;
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  PrivateTaskState? get privateTaskState =>
      activeConversation.kind == ConversationKind.direct
      ? PrivateTaskState(
          _store.database,
          activeConversation.id,
          activeConversation.defaultSenderId,
        )
      : null;

  GroupChatStore get groupStore => _store.groups;

  Future<List<Conversation>> groupConversations({
    Conversation? after,
    int limit = ConversationReader.pageSize,
  }) => _store.reader.list(
    after: after,
    limit: limit,
    kind: ConversationKind.group,
  );

  Future<void> loadEarlierMessages() async {
    if (loadingEarlierMessages || !activeConversation.hasEarlierMessages)
      return;
    loadingEarlierMessages = true;
    final conversation = activeConversation;
    try {
      final page = await _store.earlierMessages(conversation);
      conversation.messages.insertAll(0, page);
      conversation.hasEarlierMessages =
          page.length == ConversationReader.messagePageSize;
    } finally {
      loadingEarlierMessages = false;
      notifyListeners();
    }
  }

  Future<List<ConversationSearchResult>> searchConversations(
    String query,
    int offset, {
    bool includeReasoning = false,
    String? projectId,
  }) => _store.reader.search(
    query,
    offset,
    includeReasoning: includeReasoning,
    projectId: projectId,
  );

  Future<List<AttachmentSearchResult>> searchAttachments(
    String query,
    int offset, {
    int limit = AttachmentSearch.pageSize,
    String? projectId,
  }) => AttachmentSearch(
    _store.database,
    _imageStore.directory,
  ).search(query, offset, limit: limit, projectId: projectId);

  void updateDraft(String text) {
    final conversation = activeConversation;
    if (conversation.draft == text) return;
    conversation.draft = text;
    conversation.draftUpdatedAt = conversation.draftPreview == null
        ? null
        : DateTime.now();
  }

  Future<void> saveDraft() async {
    if (identical(activeConversation, _newConversation) &&
        !activeConversation.isEmpty) {
      await _storeNewDraft();
    } else {
      await _persist();
    }
    await _removeEmptyDraft();
    _conversationChanged();
  }

  Future<void> _storeNewDraft() async {
    final draft = _newConversation;
    if (draft.isEmpty && !draft.isStored) return;
    if (!draft.isStored) {
      draft.isStored = true;
      try {
        await _store.writer.save(
          draft,
          makeActive: identical(_viewConversation, draft),
          saveDraft: true,
          saveMessages: false,
        );
      } on Object {
        draft.isStored = false;
        rethrow;
      }
    }
    await _newDraftStore.clear(senderId: draft.defaultSenderId);
    _newConversation = Conversation.empty();
    _updateConversationList(draft);
    _conversationChanged();
  }

  Future<void> _removeEmptyDraft() async {
    final draft = activeConversation;
    if (draft.kind != ConversationKind.direct ||
        draft.messageCount != 0 ||
        !draft.isStored ||
        !draft.isEmpty)
      return;
    await _store.removeDraftConversation(draft.id);
    _conversations.removeWhere((conversation) => conversation.id == draft.id);
    if (identical(_viewConversation, draft))
      _activeConversation = _newConversation;
    _conversationChanged();
  }

  Future<void> _persist({
    Map<String, List<String>> recipients = const {},
    bool saveRuntime = false,
    bool saveMessages = false,
  }) =>
      activeConversation.kind == ConversationKind.direct &&
          activeConversation.messageCount == 0 &&
          !activeConversation.isTemporary &&
          !activeConversation.isStored
      ? _newDraftStore.save(activeConversation)
      : _store.writer.save(
          activeConversation,
          recipients: recipients,
          saveDraft: true,
          saveRuntime: saveRuntime,
          saveMessages: saveMessages,
        );

  Future<bool> getScreenAccess(String senderId) async =>
      (await groupStore.loadAi(senderId)).preferences.screenAccess;
  Future<void> setScreenAccess(String senderId, bool allowed) async {
    final ai = await groupStore.loadAi(senderId);
    await saveAi(
      ai.copyWith(preferences: ai.preferences.copyWith(screenAccess: allowed)),
    );
  }
}
