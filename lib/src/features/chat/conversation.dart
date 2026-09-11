import '../../domain/agent_models.dart';

enum ChatRunState { idle, running, stopping, failed, cancelled, interrupted }

class Conversation {
  Conversation({required this.id, required this.createdAt});

  factory Conversation.empty() =>
      Conversation(id: newMessageId(), createdAt: DateTime.now());

  final String id;
  final DateTime createdAt;
  final List<AgentMessage> messages = [];
  final List<AgentStep> steps = [];
  String draft = '';
  String? pendingGoal;
  String? errorDetail;
  ChatRunState runState = ChatRunState.idle;

  bool get isEmpty => messages.isEmpty && draft.isEmpty && pendingGoal == null;
  DateTime get updatedAt =>
      messages.isEmpty ? createdAt : messages.last.createdAt;
  String get title => messages.isEmpty
      ? (draft.isEmpty ? '新对话' : '未发送的草稿')
      : messages.first.text;
  String? get preview => draft.isNotEmpty
      ? draft
      : messages.length > 1
      ? messages.last.text
      : null;

  Map<String, Object?> toJson() => {
    'id': id,
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
    'draft': draft,
    'pendingGoal': pendingGoal,
    'errorDetail': errorDetail,
    'runState': runState.name,
  };

  factory Conversation.fromJson(
    Map<String, Object?> json, {
    bool legacy = false,
  }) {
    final conversation = legacy
        ? Conversation.empty()
        : Conversation(
            id: json['id']! as String,
            createdAt: DateTime.parse(json['createdAt']! as String),
          );
    conversation.messages.addAll(
      (json['messages']! as List<Object?>).map(
        (item) => AgentMessage.fromJson((item! as Map).cast<String, Object?>()),
      ),
    );
    conversation.pendingGoal = json['pendingGoal'] as String?;
    final state = ChatRunState.values.byName(json['runState']! as String);
    conversation.runState =
        state == ChatRunState.running || state == ChatRunState.stopping
        ? ChatRunState.interrupted
        : state;
    if (!legacy) {
      conversation.draft = json['draft']! as String;
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
