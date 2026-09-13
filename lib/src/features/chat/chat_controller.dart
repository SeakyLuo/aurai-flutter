import '../../agent/self_profile_tool.dart';
import 'avatar_symbol.dart';
import 'avatar_background.dart';
import '../../storage/conversation_visibility.dart';
import '../../domain/message_quote.dart';
import '../../agent/group_message_tool.dart';
import '../../storage/group_participation.dart';
import 'group_dispatcher.dart';
import '../../agent/group_chat_tools.dart';
import '../../agent/ai_contact_tools.dart';
import '../../platform/ai_document_scope.dart';
import '../../storage/attachment_search.dart';
import '../../storage/group_chat_store.dart';
import '../../storage/conversation_tool_history.dart';
import '../../agent/attachment_tool.dart';
import 'tool_approval_store.dart';
import '../../domain/message_file.dart';
import '../../platform/message_file_store.dart';
import '../../platform/document_tools.dart';
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
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../agent/agent_runtime.dart';
import '../../agent/system_prompt.dart';
import '../../agent/ask_user_tool.dart';
import '../../agent/model_balance_tool.dart';
import '../../agent/memory_tools.dart';
import '../../agent/model_top_up_tool.dart';
import '../../agent/tool_executor.dart';
import '../../agent/group_tool_executor.dart';
import '../../agent/tool_registry.dart';
import '../../agent/local_history_tools.dart';
import '../../agent/web_tools.dart';
import '../../agent/source_dates_tool.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../domain/ai_profile.dart';
import '../../domain/conversation_completion.dart';
import '../../domain/capability.dart';
import '../../domain/model_provider.dart';
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

export 'conversation.dart';

part 'message_quote_actions.dart';
part 'message_recall.dart';
part 'message_submission.dart';
part 'global_tools.dart';
part 'group_reply_context.dart';
part 'ai_identity_controller.dart';
part 'group_conversation_run.dart';
part 'group_message_delivery.dart';
part 'group_private_conversation.dart';
part 'group_system_events.dart';
part 'conversation_actions.dart';
part 'image_forwarding.dart';
part 'conversation_search_navigation.dart';
part 'conversation_run.dart';
part 'scheduled_execution.dart';
part 'message_edit_actions.dart';
part 'accessibility_request.dart';

class PendingConfirmation {
  PendingConfirmation(this.call, this.definition, this.conversationId)
    : deadline = call.confirmationTimeoutSeconds == null
          ? null
          : DateTime.now().add(
              Duration(seconds: call.confirmationTimeoutSeconds!),
            );
  final String conversationId;
  final DateTime? deadline;
  final ToolCall call;
  final ToolDefinition definition;
  String scope = 'once';
  final completer = Completer<bool>();
}

class ChatController extends ChangeNotifier {
  AiProfile? _activeAi;
  AiProfile? get activeAi => _activeAi;
  bool hasRestoredConversation = false;
  bool startsWithoutConversations = false;
  final Map<String, MemoryController> _aiMemories = {};
  final Map<String, SkillStore> _aiSkills = {};
  ChatController(this._platform);

  final AuraiPlatform _platform;
  final scheduledTasks = ScheduledTasks();
  final skills = SkillStore();
  final toolApprovals = ToolApprovalStore();
  String? pendingComposerDraft;

  Future<void> prepareSkillCreation() async {
    await createConversation();
    final draft = activeConversation.draft;
    activeConversation.draft =
        "${draft.isEmpty ? '' : '$draft\n\n'}帮我创建一个可复用的技能：";
    await saveDraft();
    pendingComposerDraft = activeConversation.draft;
    notifyListeners();
  }

  bool _claimingSchedule = false;
  final _imageStore = MessageImageStore();
  bool addingImages = false;
  List<MessageImage> get draftImages => activeConversation.draftImages;
  List<MessageFile> get draftFiles => activeConversation.draftFiles;
  final notificationOpenRequests = ValueNotifier<int>(0);
  Future<String?> takeNotificationConversation() =>
      _platform.takeNotificationConversation();
  final completedReplies = ValueNotifier<ConversationCompletion?>(null);
  final _store = ConversationStore();
  MemoryController? _memory;
  MemoryController get memory => _memory!;
  final _newDraftStore = NewConversationDraft();
  late Conversation _newConversation;
  final List<Conversation> _conversations = [];
  late Conversation _activeConversation;
  Conversation get activeConversation => _activeConversation;
  Conversation? _conversationCursor;
  bool hasMoreConversations = false;
  bool loadingConversations = false;
  bool loadingEarlierMessages = false;
  bool changingConversation = false;
  List<Conversation> get conversations => List.unmodifiable(
    <Conversation>[..._conversations.where((item) => !item.isArchived)]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      }),
  );
  List<AgentMessage> get messages => activeConversation.messages;
  List<AgentStep> get steps => activeConversation.steps;
  final List<Capability> capabilities = <Capability>[];
  ModelSettings modelSettings = ModelSettings.defaults();
  ChatRunState get runState => activeConversation.runState;
  set runState(ChatRunState value) => activeConversation.runState = value;
  String? get pendingGoal => activeConversation.pendingGoal;
  set pendingGoal(String? value) => activeConversation.pendingGoal = value;
  String? get errorDetail => activeConversation.errorDetail;
  set errorDetail(String? value) => activeConversation.errorDetail = value;
  bool _submitting = false;
  final _recallingMessages = <String>{};
  AgentRuntime? _runtime;
  final _queuedSystemNotices = <String, List<AgentMessage>>{};
  bool _systemEventDrainScheduled = false;
  bool _systemEventLoading = false;
  GroupDispatcher? _groupDispatcher;
  final _groupReplies = <String, _ReplyContext>{};
  final _groupSenders = <String, MessageSender>{};
  final _groupRuns = <String, Conversation>{};
  final _removedGroupMembers = <String>{};
  String? _confirmingSenderId;
  final _groupRuntimes = <String, AgentRuntime>{};
  final _groupStreaming = <String, String>{};
  final _groupToolQueue = GroupToolQueue();
  Iterable<Conversation> get groupRuns =>
      activeConversation.id == runningConversationId
      ? _groupRuns.values
      : const [];
  bool isStreamingMessage(String id) =>
      streamingMessageId == id || _groupStreaming.containsValue(id);
  bool get hasStreamingMessages =>
      streamingMessageId != null || _groupStreaming.isNotEmpty;
  Conversation? _runningConversation;
  Conversation? _privateConversation;
  bool get hasRunningTask =>
      _systemEventLoading ||
      _runningConversation != null ||
      _privateConversation != null ||
      _submitting ||
      _claimingSchedule;
  String? get runningConversationId => _runningConversation?.id;

  String? streamingMessageId;
  PendingConfirmation? pendingConfirmation;
  UserQuestion? pendingQuestion;
  Completer<Map<String, Object?>>? _accessibilityRequest;
  bool accessibilityRequestPending = false;
  Timer? _accessibilityTimer;
  DateTime? accessibilityDeadline;
  bool _accessibilitySettingsOpened = false;

  void _accessibilityChanged() => notifyListeners();

  @override
  void dispose() {
    _groupDispatcher?.stop();
    _queuedSystemNotices.clear();
    groupStore.onSystemNotice = null;
    skills.dispose();
    for (final store in _aiMemories.values) {
      store.dispose();
    }
    for (final store in _aiSkills.values) {
      store.dispose();
    }
    scheduledTasks.dispose();
    _memory?.dispose();
    _accessibilityTimer?.cancel();
    completedReplies.dispose();
    notificationOpenRequests.dispose();
    super.dispose();
  }

  final Set<String> _deniedConfirmations = <String>{};
  bool _accessibilityDeclined = false;

  bool get isBusy =>
      _submitting ||
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
      !_submitting && !_claimingSchedule && !changingConversation;

  ModelConfig get config =>
      _activeAi == null ? modelSettings.activeConfig : aiConfig(_activeAi!);

  bool get needsConfiguration => !config.isConfigured;

  bool get hasCapabilityIssue => capabilities.any(
    (capability) =>
        capability.availability == CapabilityAvailability.permissionRequired,
  );

  Future<void> initialize() async {
    _platform.setStopHandler(stop, () => notificationOpenRequests.value++);
    await _imageStore.initialize();
    await toolApprovals.initialize();
    modelSettings = await _platform.loadModelSettings();
    await refreshCapabilities();
    final activeId = await _store.initialize(
      _imageStore.directory,
      _platform.loadLegacyAppState,
      _platform.clearLegacyAppState,
    );
    groupStore.onSystemNotice = _receiveGroupSystemNotice;
    _memory = MemoryController(_store.database, () => config);
    await memory.initialize();
    await _migrateAiSettings();
    await skills.initialize(_store.database);
    _newConversation = await _newDraftStore.load(_imageStore.directory);
    if (await _store.hasMessages(_newConversation.id)) {
      await _newDraftStore.clear();
      _newConversation = Conversation.empty();
    }
    hasRestoredConversation = activeId != null;
    _activeConversation = activeId == null
        ? _newConversation
        : await _store.load(activeId);
    if (activeId != null &&
        activeConversation.kind == ConversationKind.direct &&
        activeConversation.defaultSenderId == MessageSender.aurai.id &&
        activeConversation.messageCount == 0) {
      _newConversation = activeConversation;
      await _newDraftStore.save(_newConversation);
      await _store.removeDraftConversation(activeId);
    }
    startsWithoutConversations = (await _store.database.query(
      'conversations',
      columns: ['id'],
      limit: 1,
    )).isEmpty;
    _activeAi = activeConversation.kind == ConversationKind.direct
        ? await groupStore.loadAi(activeConversation.defaultSenderId)
        : null;
    await _reloadConversations();
    await scheduledTasks.initialize(_runScheduled);
    notifyListeners();
  }

  Future<void> continuePending() async {
    if (canStartPrivateDuringGroup) {
      await _runPrivateDuringGroup();
      return;
    }
    if (hasRunningTask) throw StateError('另一个会话正在运行，请等待完成');
    if (pendingGoal == null) return;
    final conversation = activeConversation;
    _runningConversation = conversation;
    notifyListeners();
    try {
      await _executeConversation(conversation);
    } finally {
      _runningConversation = null;
      _drainGroupSystemNotices();
      _updateConversationList(conversation);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (identical(activeConversation, _privateConversation)) {
      _privateConversation!.runState = ChatRunState.stopping;
      await _runtime?.cancel();
      return;
    }
    final conversation = _runningConversation;
    if (conversation == null || conversation.runState != ChatRunState.running) {
      return;
    }
    conversation.runState = ChatRunState.stopping;
    _queuedSystemNotices.remove(conversation.id);
    _groupDispatcher?.stop();
    for (final member in _groupRuns.values) {
      if (member.runState == ChatRunState.running)
        member.runState = ChatRunState.stopping;
    }

    notifyListeners();
    await _persistRun(conversation);
    pendingConfirmation?.completer.complete(false);
    pendingConfirmation = null;
    _finishAccessibility({'granted': false, 'reason': 'User stopped the task'});
    await _platform.cancelPendingInteraction();
    await Future.wait([
      if (_runtime != null && _privateConversation == null) _runtime!.cancel(),
      for (final runtime in _groupRuntimes.values) runtime.cancel(),
    ]);
  }

  Future<void> saveConfig(ModelConfig newConfig, {String? senderId}) async {
    final nextSettings = modelSettings.activate(
      newConfig,
      systemPrompt: modelSettings.systemPrompt,
    );
    await _platform.saveModelSettings(nextSettings);
    modelSettings = nextSettings;
    groupStore.defaultSelection = AiModelSelection(
      provider: newConfig.service,
      model: newConfig.model,
      baseUrl: newConfig.baseUrl,
    );
    if (senderId != null) {
      final ai = await groupStore.loadAi(senderId);
      await saveAi(
        ai.copyWith(
          modelSelection: AiModelSelection(
            provider: newConfig.service,
            model: newConfig.model,
            baseUrl: newConfig.baseUrl,
          ),
        ),
      );
    }
    notifyListeners();
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

  Future<void> createConversation() async {
    if (identical(activeConversation, _newConversation)) return;
    await _switchConversation(null);
  }

  Future<void> selectConversation(String id) => _switchConversation(id);

  Future<void> restoreConversation(String id) =>
      _switchConversation(id == _newConversation.id ? null : id);

  final _loadedMessageCounts = <String, int>{};
  final _searchWindows = <String, Conversation>{};
  int _searchNavigationGeneration = 0;

  Future<void> _switchConversation(String? id) async {
    if (_submitting || addingImages || changingConversation)
      throw StateError('请等待当前操作完成，再切换会话');
    cancelSearchNavigation();
    changingConversation = true;
    notifyListeners();
    try {
      await _persist();
      _loadedMessageCounts[activeConversation.id] = messages.length;
      final conversation = id == null
          ? _newConversation
          : id == _privateConversation?.id
          ? _privateConversation!
          : id == _runningConversation?.id
          ? _runningConversation!
          : await _store.load(
              id,
              messageLimit:
                  (_loadedMessageCounts[id] ?? 0) <
                      ConversationReader.messagePageSize
                  ? ConversationReader.messagePageSize
                  : _loadedMessageCounts[id]!,
            );
      if (id == null) {
        await _store.selectNewConversation();
      } else {
        if (conversation.runState == ChatRunState.idle &&
            conversation.pendingGoal == null) {
          conversation.seenRunId = conversation.activeRunId;
        }
        await _store.writer.save(conversation);
      }
      final previousIndex = _conversations.indexWhere(
        (item) => item.id == activeConversation.id,
      );
      if (previousIndex >= 0 &&
          activeConversation != _runningConversation &&
          activeConversation != _privateConversation) {
        _conversations[previousIndex] =
            conversationFromRow(conversationRow(activeConversation))
              ..seenRunId = activeConversation.seenRunId
              ..draftFiles.addAll(activeConversation.draftFiles)
              ..draftImages.addAll(activeConversation.draftImages);
      }
      _activeConversation = conversation;
      _activeAi = conversation.kind == ConversationKind.direct
          ? await groupStore.loadAi(conversation.defaultSenderId)
          : null;
      _restoreSearchWindow(conversation);
      _store.writer.retain([
        ...conversation.messages,
        if (_privateConversation != null &&
            _privateConversation != conversation)
          ..._privateConversation!.messages,
        if (_runningConversation != null &&
            _runningConversation != conversation)
          ..._runningConversation!.messages,
      ]);
      _updateConversationList();
    } finally {
      changingConversation = false;
      _drainGroupSystemNotices();
      notifyListeners();
    }
  }

  void _conversationChanged() => notifyListeners();

  void _updateConversationList([Conversation? value]) {
    final conversation = value ?? activeConversation;
    if (conversation.kind == ConversationKind.direct &&
        conversation.messageCount == 0)
      return;
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index == -1) {
      _conversations.add(conversation);
    } else {
      _conversations[index] = conversation;
    }
  }

  Future<void> _reloadConversations() async {
    final page = await _store.reader.list();
    _conversations
      ..clear()
      ..addAll(
        page.map(
          (item) => item.id == activeConversation.id
              ? activeConversation
              : item.id == _runningConversation?.id
              ? _runningConversation!
              : item,
        ),
      );
    _conversationCursor = page.isEmpty ? null : page.last;
    hasMoreConversations = page.length == ConversationReader.pageSize;
  }

  Future<void> refreshConversations() async {
    if (loadingConversations) return;
    loadingConversations = true;
    try {
      await _reloadConversations();
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

  GroupChatStore get groupStore => _store.groups;

  Future<List<Conversation>> groupConversations({Conversation? after}) =>
      _store.reader.list(after: after, kind: ConversationKind.group);

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
    int offset,
  ) => _store.reader.search(query, offset);

  Future<List<AttachmentSearchResult>> searchAttachments(
    String query,
    int offset, {
    int limit = AttachmentSearch.pageSize,
  }) => AttachmentSearch(
    _store.database,
    _imageStore.directory,
  ).search(query, offset, limit: limit);

  Future<void> addImages([ImageSource? source]) async {
    addingImages = true;
    notifyListeners();
    try {
      await _persist();
      final remaining = MessageImageStore.maxImages - draftImages.length;
      final images = source == null
          ? await _imageStore.recover(remaining)
          : await _imageStore.pick(source, remaining);
      draftImages.addAll(images);
      try {
        await _persist();
      } on Object {
        draftImages.removeWhere(images.contains);
        await _imageStore.remove(images);
        rethrow;
      }
    } finally {
      addingImages = false;
      notifyListeners();
    }
  }

  Future<void> removeDraftImage(MessageImage image) async {
    final index = draftImages.indexOf(image);
    draftImages.removeAt(index);
    notifyListeners();
    try {
      await _persist();
    } on Object {
      draftImages.insert(index, image);
      notifyListeners();
      rethrow;
    }
    await _imageStore.remove([image]);
  }

  Future<List<MessageFile>> pickFiles(int remaining) =>
      MessageFileStore.pick(_imageStore.directory, remaining);

  Future<void> addFiles() async {
    addingImages = true;
    notifyListeners();
    try {
      await _persist();
      final files = await pickFiles(
        MessageFileStore.maxFiles - draftFiles.length,
      );
      draftFiles.addAll(files);
      try {
        await _persist();
      } on Object {
        draftFiles.removeWhere(files.contains);
        await MessageFileStore.remove(files);
        rethrow;
      }
    } finally {
      addingImages = false;
      notifyListeners();
    }
  }

  Future<void> removeDraftFile(MessageFile file) async {
    final index = draftFiles.indexOf(file);
    draftFiles.removeAt(index);
    notifyListeners();
    try {
      await _persist();
    } on Object {
      draftFiles.insert(index, file);
      notifyListeners();
      rethrow;
    }
    await MessageFileStore.remove([file]);
  }

  Future<void> saveDraft() => _persist();

  Future<void> _persist({Map<String, List<String>> recipients = const {}}) =>
      activeConversation.kind == ConversationKind.direct &&
          activeConversation.defaultSenderId == MessageSender.aurai.id &&
          activeConversation.messageCount == 0
      ? _newDraftStore.save(activeConversation)
      : _store.writer.save(activeConversation, recipients: recipients);

  Future<bool> getScreenAccess(String senderId) async =>
      (await groupStore.loadAi(senderId)).preferences.screenAccess;
  Future<void> setScreenAccess(String senderId, bool allowed) async {
    final ai = await groupStore.loadAi(senderId);
    await saveAi(
      ai.copyWith(preferences: ai.preferences.copyWith(screenAccess: allowed)),
    );
  }

  Future<bool> _confirm(
    ToolCall call,
    ToolDefinition definition, {
    String? runId,
    String senderId = 'agent:aurai',
    bool screenAccess = false,
  }) async {
    if (_removedGroupMembers.contains(senderId) &&
        _groupRuns.containsKey(senderId))
      return false;
    final fingerprint = '$senderId:${call.name}:${jsonEncode(call.arguments)}';
    if (_deniedConfirmations.contains(fingerprint)) return false;
    final accessibilityAvailable = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    final approvalId = await _store.runs.requestApproval(
      runId ?? _runningConversation!.activeRunId!,
      call,
      definition,
    );
    final conversationId = _runningConversation!.id;
    final existing =
        (screenAccess && isScreenTool(call.name)) ||
        toolApprovals.allows(conversationId, call, senderId: senderId);
    if (!existing)
      await _platform.updateAttentionNotification(
        conversationId,
        'approval',
        title: '等待你的授权',
        body: definition.confirmationDescriptionFor(call.arguments),
        timeoutSeconds: call.confirmationTimeoutSeconds,
      );
    _confirmingSenderId = senderId;
    final bool approved;
    try {
      final scope = accessibilityAvailable
          ? await _platform.requestConfirmation(
              call.id,
              call.name,
              call.arguments,
              '${definition.confirmationDescriptionFor(call.arguments) ?? definition.description}\n\n授权对象：${call.name == 'runSkill' ? call.arguments['name'] : toolTitle(call.name)}',
              definition.taskScopedConfirmation,
              call.confirmationTimeoutSeconds,
              autoApproved: existing,
            )
          : existing
          ? 'once'
          : await _confirmInApp(call, definition);
      approved = scope != 'deny';
      if (approved) {
        await toolApprovals.grant(
          conversationId,
          call,
          call.name == 'runSkill'
              ? '技能：${call.arguments['name']}（版本 ${call.arguments['revision']}）'
              : toolTitle(call.name),
          scope,
          senderId: senderId,
        );
      }
    } finally {
      _confirmingSenderId = null;
      await _platform.updateAttentionNotification(conversationId, 'approval');
    }
    await _store.runs.resolveApproval(approvalId, approved);
    if (!approved) _deniedConfirmations.add(fingerprint);
    return approved;
  }

  Future<String> _confirmInApp(ToolCall call, ToolDefinition definition) async {
    final request = PendingConfirmation(
      call,
      definition,
      _runningConversation!.id,
    );
    pendingConfirmation = request;
    notifyListeners();
    final timer = call.confirmationTimeoutSeconds == null
        ? null
        : Timer(Duration(seconds: call.confirmationTimeoutSeconds!), () {
            if (identical(pendingConfirmation, request))
              resolveConfirmation(false);
          });
    try {
      final approved = await request.completer.future;
      return approved ? request.scope : 'deny';
    } finally {
      timer?.cancel();
    }
  }
}
