import '../../agent/attachment_tool.dart';
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
import '../../agent/ask_user_tool.dart';
import '../../agent/model_balance_tool.dart';
import '../../agent/memory_tools.dart';
import '../../agent/model_top_up_tool.dart';
import '../../agent/tool_executor.dart';
import '../../agent/tool_registry.dart';
import '../../agent/local_history_tools.dart';
import '../../agent/web_tools.dart';
import '../../agent/source_dates_tool.dart';
import '../../domain/agent_models.dart';
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

part 'conversation_actions.dart';
part 'conversation_run.dart';
part 'scheduled_execution.dart';
part 'message_edit_actions.dart';
part 'accessibility_request.dart';

class PendingConfirmation {
  PendingConfirmation(this.call, this.definition)
    : deadline = DateTime.now().add(
        Duration(seconds: call.confirmationTimeoutSeconds!),
      );
  final DateTime deadline;
  final ToolCall call;
  final ToolDefinition definition;
  final completer = Completer<bool>();
}

class ChatController extends ChangeNotifier {
  ChatController(this._platform);

  final AuraiPlatform _platform;
  final scheduledTasks = ScheduledTasks();
  final skills = SkillStore();
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
  AgentRuntime? _runtime;
  Conversation? _runningConversation;
  bool get hasRunningTask =>
      _runningConversation != null || _submitting || _claimingSchedule;
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
    skills.dispose();
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
      runState == ChatRunState.running ||
      runState == ChatRunState.stopping;

  ModelConfig get config => modelSettings.activeConfig;

  bool get needsConfiguration => !config.isConfigured;

  bool get hasCapabilityIssue => capabilities.any(
    (capability) =>
        capability.availability == CapabilityAvailability.permissionRequired,
  );

  Future<void> initialize() async {
    _platform.setStopHandler(stop, () => notificationOpenRequests.value++);
    await _imageStore.initialize();
    modelSettings = await _platform.loadModelSettings();
    await refreshCapabilities();
    final activeId = await _store.initialize(
      _imageStore.directory,
      _platform.loadLegacyAppState,
      _platform.clearLegacyAppState,
    );
    _memory = MemoryController(_store.database, () => config);
    await memory.initialize();
    await skills.initialize(_store.database);
    _newConversation = await _newDraftStore.load(_imageStore.directory);
    if (await _store.hasMessages(_newConversation.id)) {
      await _newDraftStore.clear();
      _newConversation = Conversation.empty();
    }
    _activeConversation = activeId == null
        ? _newConversation
        : await _store.load(activeId);
    if (activeId != null && activeConversation.messageCount == 0) {
      _newConversation = activeConversation;
      await _newDraftStore.save(_newConversation);
      await _store.removeDraftConversation(activeId);
    }
    await _reloadConversations();
    await scheduledTasks.initialize(_runScheduled);
    notifyListeners();
  }

  Future<bool> submitGoal(String goal) async {
    if (hasRunningTask) throw StateError('另一个会话正在运行，请等待完成');
    _submitting = true;
    final wasNew = activeConversation.messageCount == 0;
    final previousDraft = activeConversation.draft;
    try {
      if (wasNew) await _newDraftStore.save(activeConversation);
      activeConversation.draft = '';
      messages.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.user,
          text: goal,
          images: List.unmodifiable(draftImages),
          files: List.unmodifiable(draftFiles),
          createdAt: DateTime.now(),
        ),
      );
      activeConversation.messageCount++;
      draftImages.clear();
      draftFiles.clear();
      pendingGoal = goal;
      steps.clear();
      activeConversation.liveToolSteps.clear();
      errorDetail = null;
      runState = ChatRunState.idle;
      notifyListeners();
      try {
        await _persist();
      } on Object {
        final unsent = messages.removeLast();
        activeConversation.messageCount--;
        activeConversation.draft = previousDraft;
        draftImages.addAll(unsent.images);
        draftFiles.addAll(unsent.files);
        pendingGoal = null;
        rethrow;
      }
      if (wasNew) {
        _newConversation = Conversation.empty();
        await _newDraftStore.clear();
      }
      _updateConversationList();
      if (needsConfiguration) {
        return true;
      }
      _submitting = false;
      await continuePending();
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> continuePending() async {
    if (hasRunningTask) throw StateError('另一个会话正在运行，请等待完成');
    if (pendingGoal == null) return;
    final conversation = activeConversation;
    _runningConversation = conversation;
    notifyListeners();
    try {
      await _executeConversation(conversation);
    } finally {
      _runningConversation = null;
      _updateConversationList(conversation);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final conversation = _runningConversation;
    if (conversation == null || conversation.runState != ChatRunState.running) {
      return;
    }
    conversation.runState = ChatRunState.stopping;
    notifyListeners();
    await _persistRun(conversation);
    pendingConfirmation?.completer.complete(false);
    pendingConfirmation = null;
    _finishAccessibility({'granted': false, 'reason': 'User stopped the task'});
    await _platform.cancelPendingInteraction();
    await _runtime?.cancel();
  }

  Future<void> saveConfig(ModelConfig newConfig) async {
    final nextSettings = modelSettings.activate(
      newConfig,
      systemPrompt: modelSettings.systemPrompt,
    );
    await _platform.saveModelSettings(nextSettings);
    modelSettings = nextSettings;
    notifyListeners();
  }

  Future<void> savePersonalization({
    required String? systemPrompt,
    required String customInstructions,
    required ResponsePreferences responsePreferences,
  }) async {
    final nextSettings = ModelSettings(
      activeService: modelSettings.activeService,
      profiles: modelSettings.profiles,
      systemPrompt: systemPrompt,
      customInstructions: customInstructions,
      responsePreferences: responsePreferences,
    );
    await _platform.saveModelSettings(nextSettings);
    modelSettings = nextSettings;
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

  final _loadedMessageCounts = <String, int>{};

  Future<void> _switchConversation(String? id) async {
    if (_submitting || addingImages || changingConversation)
      throw StateError('请等待当前操作完成，再切换会话');
    changingConversation = true;
    notifyListeners();
    try {
      await _persist();
      _loadedMessageCounts[activeConversation.id] = messages.length;
      final conversation = id == null
          ? _newConversation
          : id == _runningConversation?.id
          ? _runningConversation!
          : await _store.load(
              id,
              messageLimit:
                  _loadedMessageCounts[id] ??
                  ConversationReader.messagePageSize,
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
      if (previousIndex >= 0 && activeConversation != _runningConversation) {
        _conversations[previousIndex] =
            conversationFromRow(conversationRow(activeConversation))
              ..seenRunId = activeConversation.seenRunId
              ..draftFiles.addAll(activeConversation.draftFiles)
              ..draftImages.addAll(activeConversation.draftImages);
      }
      _activeConversation = conversation;
      _store.writer.retain([
        ...conversation.messages,
        if (_runningConversation != null &&
            _runningConversation != conversation)
          ..._runningConversation!.messages,
      ]);
      _updateConversationList();
    } finally {
      changingConversation = false;
      notifyListeners();
    }
  }

  void _conversationChanged() => notifyListeners();

  void _updateConversationList([Conversation? value]) {
    final conversation = value ?? activeConversation;
    if (conversation.messageCount == 0) return;
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

  Future<void> _persist() => activeConversation.messageCount == 0
      ? _newDraftStore.save(activeConversation)
      : _store.writer.save(activeConversation);

  Future<bool> getScreenAccess() => _platform.getScreenAccess();
  Future<void> setScreenAccess(bool allowed) =>
      _platform.setScreenAccess(allowed);

  Future<bool> _confirm(ToolCall call, ToolDefinition definition) async {
    final fingerprint = '${call.name}:${jsonEncode(call.arguments)}';
    if (_deniedConfirmations.contains(fingerprint)) return false;
    final accessibilityAvailable = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    final approvalId = await _store.runs.requestApproval(
      _runningConversation!.activeRunId!,
      call,
      definition,
    );
    final conversationId = _runningConversation!.id;
    await _platform.updateAttentionNotification(
      conversationId,
      'approval',
      title: '等待你的授权',
      body: definition.confirmationDescriptionFor(call.arguments),
      timeoutSeconds: call.confirmationTimeoutSeconds!,
    );
    final bool approved;
    try {
      approved = accessibilityAvailable
          ? await _platform.requestConfirmation(
              call.id,
              call.name,
              call.arguments,
              definition.confirmationDescriptionFor(call.arguments),
              definition.taskScopedConfirmation,
              call.confirmationTimeoutSeconds!,
            )
          : await _confirmInApp(call, definition);
    } finally {
      await _platform.updateAttentionNotification(conversationId, 'approval');
    }
    await _store.runs.resolveApproval(approvalId, approved);
    if (!approved) _deniedConfirmations.add(fingerprint);
    return approved;
  }

  Future<bool> _confirmInApp(ToolCall call, ToolDefinition definition) async {
    final screenAccess = isScreenTool(call.name);
    if (screenAccess && await _platform.getScreenAccess()) return true;
    final request = PendingConfirmation(call, definition);
    pendingConfirmation = request;
    notifyListeners();
    final timer = Timer(
      Duration(seconds: call.confirmationTimeoutSeconds!),
      () {
        if (identical(pendingConfirmation, request)) resolveConfirmation(false);
      },
    );
    try {
      final approved = await request.completer.future;
      if (approved && screenAccess) await _platform.setScreenAccess(true);
      return approved;
    } finally {
      timer.cancel();
    }
  }
}
