import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../agent/agent_runtime.dart';
import '../../agent/tool_executor.dart';
import '../../agent/tool_registry.dart';
import '../../domain/agent_models.dart';
import '../../domain/capability.dart';
import '../../domain/model_provider.dart';
import '../../domain/tool_models.dart';
import '../../platform/android_network_tools.dart';
import '../../platform/android_agent_tools.dart';
import '../../platform/android_notification_tools.dart';
import '../../platform/aurai_platform.dart';
import '../../providers/deepseek_responses_provider.dart';
import '../../providers/openai_responses_provider.dart';
import 'conversation.dart';

export 'conversation.dart';

class PendingConfirmation {
  PendingConfirmation(this.call, this.definition);
  final ToolCall call;
  final ToolDefinition definition;
  final completer = Completer<bool>();
}

class ChatController extends ChangeNotifier {
  ChatController(this._platform);

  final AuraiPlatform _platform;
  final List<Conversation> _conversations = [Conversation.empty()];
  int _activeIndex = 0;
  Conversation get activeConversation => _conversations[_activeIndex];
  List<Conversation> get conversations => List.unmodifiable(
    <Conversation>[..._conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
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
  Future<void> _saving = Future.value();
  bool _submitting = false;
  AgentRuntime? _runtime;
  PendingConfirmation? pendingConfirmation;
  Completer<Map<String, Object?>>? _accessibilityRequest;
  bool accessibilityRequestPending = false;
  final Set<String> _deniedConfirmations = <String>{};
  bool _accessibilityDeclined = false;

  bool get isBusy =>
      _submitting ||
      _runtime != null ||
      runState == ChatRunState.running ||
      runState == ChatRunState.stopping;

  ModelConfig get config => modelSettings.activeConfig;

  bool get needsConfiguration => !config.isConfigured;

  bool get hasCapabilityIssue => capabilities.any(
    (capability) =>
        capability.availability == CapabilityAvailability.permissionRequired,
  );

  Future<void> initialize() async {
    _platform.setStopHandler(stop);
    modelSettings = await _platform.loadModelSettings();
    await refreshCapabilities();
    final saved = await _platform.loadAppState();
    if (saved != null) {
      final json = (jsonDecode(saved) as Map<Object?, Object?>)
          .cast<String, Object?>();
      _conversations.clear();
      if (json['version'] == 2) {
        _conversations.addAll(
          (json['conversations']! as List<Object?>).map(
            (item) =>
                Conversation.fromJson((item! as Map).cast<String, Object?>()),
          ),
        );
        _activeIndex = _conversations.indexWhere(
          (item) => item.id == json['activeConversation'],
        );
      } else {
        _conversations.add(Conversation.fromJson(json, legacy: true));
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<bool> submitGoal(String goal) async {
    _submitting = true;
    try {
      activeConversation.draft = '';
      messages.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.user,
          text: goal,
          createdAt: DateTime.now(),
        ),
      );
      pendingGoal = goal;
      steps.clear();
      errorDetail = null;
      runState = ChatRunState.idle;
      notifyListeners();
      await _persist();
      if (needsConfiguration) {
        return true;
      }
      await continuePending();
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> continuePending() async {
    if (pendingGoal == null ||
        _runtime != null ||
        runState == ChatRunState.running ||
        runState == ChatRunState.stopping) {
      return;
    }
    steps.clear();
    errorDetail = null;
    runState = ChatRunState.running;
    _deniedConfirmations.clear();
    _accessibilityDeclined = false;
    notifyListeners();
    await _persist();
    var sessionStarted = false;
    var outcome = 'failed';
    try {
      await refreshCapabilities();
      if (runState == ChatRunState.stopping) throw const AgentCancelled();
      final provider = switch (config.service) {
        ModelService.openAi => OpenAiResponsesProvider(config),
        ModelService.deepSeek => DeepSeekResponsesProvider(config),
      };
      final tools = <AgentTool>[
        GetNetworkStateTool(_platform),
        GetNetworkEventsTool(_platform),
        DnsLookupTool(_platform),
        TlsProbeTool(_platform),
        HttpProbeTool(_platform),
        GetNotificationsTool(_platform, config.service.label),
        ObserveDeviceTool(_platform),
        if (provider.supportsImageInput)
          CaptureScreenTool(_platform, config.service.label),
        if (provider.supportsImageInput) TapScreenTool(_platform),
        WaitTool(),
        RequestAccessibilityAccessTool(_requestAccessibility),
        ActTool(_platform),
        FindAppsTool(_platform),
        LaunchAppTool(_platform),
        StartIntentTool(_platform),
        OpenSettingsTool(_platform),
        AppShellTool(_platform),
      ];
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      final executor = ToolExecutor(registry: registry, confirm: _confirm);
      _runtime = AgentRuntime(
        provider: provider,
        registry: registry,
        executor: executor,
      );
      await _platform.startAgentSession();
      sessionStarted = true;
      if (runState == ChatRunState.stopping) throw const AgentCancelled();
      final result = await _runtime!.run(
        conversation: List.unmodifiable(messages),
        onStepsChanged: (newSteps) {
          steps
            ..clear()
            ..addAll(newSteps);
          final runningStep = newSteps.where(
            (step) => step.status == AgentStepStatus.running,
          );
          unawaited(
            _platform.updateAgentSessionStep(
              runningStep.isEmpty ? '正在分析结果' : runningStep.last.title,
            ),
          );
          notifyListeners();
        },
      );
      messages.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.assistant,
          text: result.answer,
          createdAt: DateTime.now(),
        ),
      );
      pendingGoal = null;
      runState = ChatRunState.idle;
      outcome = 'completed';
    } on Object catch (error) {
      if (runState == ChatRunState.stopping || error is AgentCancelled) {
        runState = ChatRunState.cancelled;
        outcome = 'cancelled';
      } else {
        runState = ChatRunState.failed;
        errorDetail = switch (error) {
          ModelProviderException() => error.message,
          PlatformException() => error.message ?? '设备能力调用失败',
          _ => '任务执行失败',
        };
      }
      rethrow;
    } finally {
      if (sessionStarted) await _platform.endAgentSession(outcome);
      _runtime = null;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> stop() async {
    if (runState != ChatRunState.running) {
      return;
    }
    runState = ChatRunState.stopping;
    notifyListeners();
    await _persist();
    pendingConfirmation?.completer.complete(false);
    pendingConfirmation = null;
    _accessibilityRequest?.complete(const <String, Object?>{
      'granted': false,
      'reason': 'User stopped the task',
    });
    _accessibilityRequest = null;
    accessibilityRequestPending = false;
    await _platform.cancelPendingInteraction();
    await _runtime?.cancel();
  }

  Future<void> saveConfig(ModelConfig newConfig) async {
    final nextSettings = modelSettings.activate(newConfig);
    await _platform.saveModelSettings(nextSettings);
    modelSettings = nextSettings;
    await refreshCapabilities();
    notifyListeners();
  }

  Future<void> refreshCapabilities() async {
    final loaded = await _platform.loadCapabilities();
    capabilities
      ..clear()
      ..addAll(
        loaded.map(
          (capability) =>
              capability.id == 'android.vision' &&
                  !modelSettings.activeConfig.supportsImageInput
              ? const Capability(
                  id: 'android.vision',
                  name: '屏幕视觉',
                  availability: CapabilityAvailability.unsupported,
                  reason: '当前模型配置未开启图像输入',
                )
              : capability,
        ),
      );
    notifyListeners();
  }

  Future<Map<String, Object?>> getBackgroundRunReadiness() =>
      _platform.getBackgroundRunReadiness();

  Future<bool> requestNotificationPermission() =>
      _platform.requestNotificationPermission();

  Future<void> openNotificationSettings() =>
      _platform.openNotificationSettings();

  Future<void> openNotificationAccessSettings() async {
    await _platform.openSettings('notificationAccess');
  }

  Future<void> openAccessibilitySettings() =>
      _platform.openAccessibilitySettings();

  Future<void> openBatterySettings() => _platform.openBatterySettings();

  Future<void> checkAccessibilityReturn() async {
    if (!accessibilityRequestPending) return;
    await refreshCapabilities();
    final granted = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    if (granted) {
      _accessibilityRequest!.complete(const <String, Object?>{
        'granted': true,
        'next': 'Call observeDevice again before acting',
      });
      _accessibilityRequest = null;
      accessibilityRequestPending = false;
      notifyListeners();
    }
  }

  void cancelAccessibilityRequest() {
    final request = _accessibilityRequest;
    if (request == null) return;
    request.complete(const <String, Object?>{
      'granted': false,
      'reason': 'User declined accessibility access for this task',
    });
    _accessibilityRequest = null;
    accessibilityRequestPending = false;
    _accessibilityDeclined = true;
    notifyListeners();
  }

  void resolveConfirmation(bool approved) {
    final request = pendingConfirmation;
    if (request == null) return;
    request.completer.complete(approved);
    pendingConfirmation = null;
    notifyListeners();
  }

  Future<void> clearConversation() async {
    if (isBusy) {
      return;
    }
    messages.clear();
    steps.clear();
    pendingGoal = null;
    errorDetail = null;
    runState = ChatRunState.idle;
    notifyListeners();
    await _persist();
  }

  Future<void> createConversation() async {
    if (isBusy) throw StateError('请先停止当前任务，再新建会话');
    final emptyIndex = _conversations.indexWhere((item) => item.isEmpty);
    if (emptyIndex == -1) {
      _conversations.add(Conversation.empty());
      _activeIndex = _conversations.length - 1;
    } else {
      _activeIndex = emptyIndex;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> selectConversation(String id) async {
    if (isBusy) throw StateError('请先停止当前任务，再切换会话');
    _activeIndex = _conversations.indexWhere((item) => item.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> saveDraft() => _persist();

  Future<void> _persist() {
    final state = jsonEncode({
      'version': 2,
      'activeConversation': activeConversation.id,
      'conversations': _conversations.map((item) => item.toJson()).toList(),
    });
    final write = _saving.then((_) => _platform.saveAppState(state));
    // A failed write must not block later attempts; its caller still receives the error.
    _saving = write.catchError((Object error) {});
    return write;
  }

  Future<Map<String, Object?>> _requestAccessibility() async {
    if (_accessibilityDeclined) {
      return const <String, Object?>{
        'granted': false,
        'reason': 'User already declined accessibility access for this task',
      };
    }
    if (_accessibilityRequest != null) {
      return const <String, Object?>{
        'granted': false,
        'reason': 'Accessibility request already shown for this task',
      };
    }
    _accessibilityRequest = Completer<Map<String, Object?>>();
    accessibilityRequestPending = true;
    notifyListeners();
    return _accessibilityRequest!.future;
  }

  Future<bool> _confirm(ToolCall call, ToolDefinition definition) async {
    final fingerprint = '${call.name}:${jsonEncode(call.arguments)}';
    if (_deniedConfirmations.contains(fingerprint)) return false;
    final accessibilityAvailable = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    final approved = accessibilityAvailable
        ? await _platform.requestConfirmation(
            call.id,
            call.name,
            call.arguments,
            definition.confirmationDescriptionFor(call.arguments),
            definition.taskScopedConfirmation,
          )
        : await _confirmInApp(call, definition);
    if (!approved) _deniedConfirmations.add(fingerprint);
    return approved;
  }

  Future<bool> _confirmInApp(ToolCall call, ToolDefinition definition) async {
    final request = PendingConfirmation(call, definition);
    pendingConfirmation = request;
    notifyListeners();
    return request.completer.future;
  }
}
