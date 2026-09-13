import '../../domain/agent_models.dart';
import '../../domain/context_summary.dart';
import '../../domain/message_image.dart';

enum ChatRunState { idle, running, stopping, failed, cancelled, interrupted }

class Conversation {
  Conversation({required this.id, required this.createdAt});

  factory Conversation.empty() =>
      Conversation(id: newMessageId(), createdAt: DateTime.now());

  final String id;
  final DateTime createdAt;
  final List<AgentMessage> messages = [];
  final List<AgentStep> steps = [];
  final List<({String afterMessageId, AgentStep step})> liveToolSteps = [];
  bool isPinned = false;
  bool isArchived = false;
  bool isScheduledTask = false;
  int messageCount = 0;
  String? storedTitle;
  String? storedPreview;
  DateTime? storedUpdatedAt;
  String? activeRunId;
  Stopwatch? executionWatch;
  Duration restoredExecutionElapsed = Duration.zero;
  bool hasExecutionProcess = false;
  String? executionUserMessageId;
  String? seenRunId;
  bool hasEarlierMessages = false;
  ContextSummary? contextSummary;
  String draft = '';
  final List<MessageImage> draftImages = [];
  String? pendingGoal;
  String? errorDetail;
  ChatRunState runState = ChatRunState.idle;
  int reconnectAttempt = 0;

  bool get isEmpty =>
      messageCount == 0 &&
      messages.isEmpty &&
      draft.isEmpty &&
      draftImages.isEmpty &&
      pendingGoal == null;
  DateTime get updatedAt =>
      messages.isEmpty ? storedUpdatedAt ?? createdAt : messages.last.createdAt;
  String get title => storedTitle != null
      ? storedTitle!
      : messages.isEmpty
      ? (draft.isEmpty && draftImages.isEmpty ? '新对话' : '未发送的草稿')
      : (messages.first.text.isEmpty ? '图片对话' : messages.first.text);
  String? get preview => draft.isNotEmpty
      ? draft
      : draftImages.isNotEmpty
      ? '未发送的图片'
      : messages.length > 1 ||
            (messages.isNotEmpty && messages.last.images.isNotEmpty)
      ? (messages.last.text.isEmpty ? '[图片]' : messages.last.text)
      : storedPreview;

  Map<String, Object?> toJson() => {
    'id': id,
    if (contextSummary != null) 'contextSummary': contextSummary!.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
    'steps': steps
        .map(
          (step) => {
            'toolName': step.toolName,
            'title': step.title,
            'status': step.status.name,
            'detail': step.detail,
          },
        )
        .toList(),
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isScheduledTask': isScheduledTask,
    'draft': draft,
    'draftImages': draftImages.map((image) => image.toJson()).toList(),
    'pendingGoal': pendingGoal,
    'errorDetail': errorDetail,
    'runState': runState.name,
  };

  factory Conversation.fromJson(
    Map<String, Object?> json, {
    bool legacy = false,
    required String imageDirectory,
  }) {
    final conversation = legacy
        ? Conversation.empty()
        : Conversation(
            id: json['id']! as String,
            createdAt: DateTime.parse(json['createdAt']! as String),
          );
    if (json['contextSummary'] != null) {
      conversation.contextSummary = ContextSummary.fromJson(
        (json['contextSummary']! as Map).cast<String, Object?>(),
      );
    }
    conversation.messages.addAll(
      (json['messages']! as List<Object?>).map(
        (item) => AgentMessage.fromJson(
          (item! as Map).cast<String, Object?>(),
          imageDirectory: imageDirectory,
        ),
      ),
    );
    conversation.messageCount = conversation.messages.length;
    conversation.isPinned = json['isPinned'] == true;
    conversation.isArchived = json['isArchived'] == true;
    conversation.isScheduledTask = json['isScheduledTask'] == true;
    conversation.pendingGoal = json['pendingGoal'] as String?;
    final state = ChatRunState.values.byName(json['runState']! as String);
    conversation.runState =
        state == ChatRunState.running || state == ChatRunState.stopping
        ? ChatRunState.interrupted
        : state;
    if (!legacy) {
      conversation.draft = json['draft']! as String;
      conversation.draftImages.addAll(
        (json['draftImages'] as List? ?? const []).map(
          (image) => MessageImage.fromJson(
            (image as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        ),
      );
      conversation.errorDetail = json['errorDetail'] as String?;
      conversation.steps.addAll(
        (json['steps']! as List<Object?>).map((item) {
          final step = (item! as Map).cast<String, Object?>();
          final status = AgentStepStatus.values.byName(
            step['status']! as String,
          );
          return AgentStep(
            toolName: step['toolName']! as String,
            title: step['title']! as String,
            status: status == AgentStepStatus.running
                ? AgentStepStatus.cancelled
                : status,
            detail: step['detail'] as String?,
          );
        }),
      );
    }
    return conversation;
  }
}
