import '../../providers/shared_responses_context.dart';
import '../../domain/message_summary.dart';
import '../../domain/draft_mention.dart';
import '../../domain/message_quote.dart';
import '../../domain/message_file.dart';
import '../../domain/message_sender.dart';
import '../../domain/agent_models.dart';
import '../../domain/context_summary.dart';
import '../../domain/message_image.dart';

enum ConversationKind { direct, group }

enum ConversationMode { normal, temporaryPersonalized, temporaryPlain }

enum ChatRunState { idle, running, stopping, failed, cancelled, interrupted }

class Conversation {
  Conversation({required this.id, required this.createdAt});

  factory Conversation.empty() =>
      Conversation(id: newMessageId(), createdAt: DateTime.now());

  final String id;
  final Map<String, String> pendingQuestionPreviews = {};
  String? get questionPreview => pendingQuestionPreviews.values.lastOrNull;
  bool isStored = false;
  ConversationKind kind = ConversationKind.direct;
  ConversationMode mode = ConversationMode.normal;
  bool get isTemporary => mode != ConversationMode.normal;
  bool get usesPersonalization => mode != ConversationMode.temporaryPlain;
  String get modeLabel => usesPersonalization ? '临时 · 个性化' : '临时 · 非个性化';
  String defaultSenderId = MessageSender.aurai.id;
  final DateTime createdAt;
  final List<AgentMessage> messages = [];
  List<AgentMessage>? searchMessages;
  String? searchMessageId;
  bool searchHasEarlier = false;
  bool searchHasLater = false;
  bool loadingSearchPage = false;
  final List<AgentStep> steps = [];
  final List<({String runId, String afterMessageId, AgentStep step})>
  liveToolSteps = [];
  bool isPinned = false;
  bool isArchived = false;
  bool isScheduledTask = false;
  int messageCount = 0;
  String? storedTitle;
  List<String> creationMemberIds = [];
  List<MessageSender> creationMembers = [];
  String creationUserName = MessageSender.localUser.name;
  String? storedPreview;
  bool storedPreviewIsSystem = false;
  AgentMessage? get _previewMessage => messages.reversed
      .where(
        (message) =>
            !message.isReasoning &&
            message.quickReplyToId == null &&
            (message.interactive?.canView(MessageSender.localUser.id) ??
                true) &&
            !(message.isSystem && message.text == '私密交互消息已更新'),
      )
      .firstOrNull;
  bool get previewIsSystem =>
      draft.isEmpty &&
      draftFiles.isEmpty &&
      draftImages.isEmpty &&
      (_previewMessage?.isSystem ?? storedPreviewIsSystem);
  DateTime? storedUpdatedAt;
  DateTime? lastMessageAt;
  String? activeRunId;
  String? replyingSenderName;
  Stopwatch? executionWatch;
  Duration restoredExecutionElapsed = Duration.zero;
  bool hasExecutionProcess = false;
  String? executionUserMessageId;
  String? seenRunId;
  int unreadMessageCount = 0;
  int groupReadAt = 0;
  String groupReadId = '';
  bool get needsGroupReadCheckpoint {
    final latest = _previewMessage;
    if (latest == null) return false;
    final at = latest.createdAt.microsecondsSinceEpoch;
    return at > groupReadAt ||
        (at == groupReadAt && latest.id.compareTo(groupReadId) > 0);
  }

  bool hasEarlierMessages = false;
  ContextSummary? contextSummary;
  SharedResponsesContext? sharedContext;
  void beginSharedContext() =>
      sharedContext = SharedResponsesContext(contextSummary);
  bool isCompacting = false;
  MessageQuote? draftQuote;
  String draft = '';
  final List<DraftMention> draftMentions = [];
  final List<MessageImage> draftImages = [];
  final List<MessageFile> draftFiles = [];
  String? pendingGoal;
  String? errorDetail;
  ChatRunState runState = ChatRunState.idle;
  int reconnectAttempt = 0;
  bool thinkingHidden = false;

  bool get isEmpty =>
      messageCount == 0 &&
      messages.isEmpty &&
      draft.isEmpty &&
      draftImages.isEmpty &&
      draftFiles.isEmpty &&
      pendingGoal == null;
  DateTime get updatedAt {
    final latest = messages.isEmpty ? createdAt : messages.last.createdAt;
    final stored = storedUpdatedAt;
    return stored != null && stored.isAfter(latest) ? stored : latest;
  }

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
      : '${creationUserName}邀请了 ${creationMembers.map((sender) => sender.name).join('、')} 加入群聊';

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

  String? get preview {
    if (questionPreview != null) return questionPreview;
    if (draftPreview != null) return draftPreview;
    final latest = _previewMessage;
    if (latest != null)
      return MessageSummary.fromMessage(latest, withSender: true);
    return storedPreview ?? creationMessage;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'mode': mode.name,
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
    conversation.mode = ConversationMode.values.byName(
      json['mode'] as String? ?? 'normal',
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
