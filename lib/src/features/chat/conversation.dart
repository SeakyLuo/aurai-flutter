import '../../domain/draft_mention.dart';
import '../../domain/message_quote.dart';
import '../../domain/message_file.dart';
import '../../domain/message_sender.dart';
import '../../domain/agent_models.dart';
import '../../domain/context_summary.dart';
import '../../domain/message_image.dart';

enum ConversationKind { direct, group }

enum ChatRunState { idle, running, stopping, failed, cancelled, interrupted }

class Conversation {
  Conversation({required this.id, required this.createdAt});

  factory Conversation.empty() =>
      Conversation(id: newMessageId(), createdAt: DateTime.now());

  final String id;
  ConversationKind kind = ConversationKind.direct;
  String defaultSenderId = MessageSender.aurai.id;
  final DateTime createdAt;
  final List<AgentMessage> messages = [];
  List<AgentMessage>? searchMessages;
  String? searchMessageId;
  bool searchHasEarlier = false;
  bool searchHasLater = false;
  bool loadingSearchPage = false;
  final List<AgentStep> steps = [];
  final List<({String afterMessageId, AgentStep step})> liveToolSteps = [];
  bool isPinned = false;
  bool isArchived = false;
  bool isScheduledTask = false;
  int messageCount = 0;
  String? storedTitle;
  List<String> creationMemberIds = [];
  List<MessageSender> creationMembers = [];
  String? storedPreview;
  bool storedPreviewIsSystem = false;
  bool get previewIsSystem =>
      draft.isEmpty &&
      draftFiles.isEmpty &&
      draftImages.isEmpty &&
      (messages.isNotEmpty ? messages.last.isSystem : storedPreviewIsSystem);
  DateTime? storedUpdatedAt;
  String? activeRunId;
  String? replyingSenderName;
  Stopwatch? executionWatch;
  Duration restoredExecutionElapsed = Duration.zero;
  bool hasExecutionProcess = false;
  String? executionUserMessageId;
  String? seenRunId;
  bool hasEarlierMessages = false;
  ContextSummary? contextSummary;
  MessageQuote? draftQuote;
  String draft = '';
  final List<DraftMention> draftMentions = [];
  final List<MessageImage> draftImages = [];
  final List<MessageFile> draftFiles = [];
  String? pendingGoal;
  String? errorDetail;
  ChatRunState runState = ChatRunState.idle;
  int reconnectAttempt = 0;

  bool get isEmpty =>
      messageCount == 0 &&
      messages.isEmpty &&
      draft.isEmpty &&
      draftImages.isEmpty &&
      draftFiles.isEmpty &&
      pendingGoal == null;
  DateTime get updatedAt =>
      messages.isEmpty ? storedUpdatedAt ?? createdAt : messages.last.createdAt;
  String get title => storedTitle != null
      ? storedTitle!
      : messages.isEmpty
      ? (draft.isEmpty && draftImages.isEmpty && draftFiles.isEmpty
            ? '新对话'
            : '未发送的草稿')
      : (messages.first.text.isEmpty
            ? (messages.first.files.isEmpty
                  ? '图片对话'
                  : messages.first.files.first.name)
            : messages.first.text);
  String? get creationMessage => creationMembers.isEmpty
      ? null
      : '你邀请了 ${creationMembers.map((sender) => sender.name).join('、')} 加入群聊';

  String? storedDraftAttachmentPreview;
  String? get draftPreview {
    final parts = [
      if (draftImages.isNotEmpty) '[图片]',
      for (final file in draftFiles) '[文件] ${file.name}',
      if (storedDraftAttachmentPreview != null) storedDraftAttachmentPreview!,
      if (draft.isNotEmpty) draft,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return draftQuote == null ? null : '[引用] ${draftQuote!.text}';
  }

  String? get preview => draft.isNotEmpty
      ? draft
      : draftFiles.isNotEmpty
      ? '未发送的附件'
      : draftImages.isNotEmpty
      ? '未发送的图片'
      : messages.isNotEmpty &&
            messages.last.files.isNotEmpty &&
            messages.last.text.isEmpty
      ? '[附件] ${messages.last.files.first.name}'
      : (kind == ConversationKind.group && messages.isNotEmpty) ||
            messages.length > 1 ||
            (messages.isNotEmpty && messages.last.images.isNotEmpty)
      ? (messages.last.text.isEmpty ? '[图片]' : messages.last.text)
      : storedPreview ?? creationMessage;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'creationMemberIds': creationMemberIds,
    'defaultSenderId': defaultSenderId,
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
    'draftFiles': draftFiles.map((file) => file.toJson()).toList(),
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
    conversation.kind = ConversationKind.values.byName(
      json['kind'] as String? ?? 'direct',
    );
    conversation.defaultSenderId =
        json['defaultSenderId'] as String? ?? MessageSender.aurai.id;
    conversation.creationMemberIds =
        (json['creationMemberIds'] as List? ?? const []).cast<String>();
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
      conversation.draftFiles.addAll(
        (json['draftFiles'] as List? ?? const []).map(
          (file) => MessageFile.fromJson(
            (file as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        ),
      );
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
