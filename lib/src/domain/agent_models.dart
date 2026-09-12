import 'message_image.dart';

enum AgentMessageRole { user, assistant }

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.images = const [],
    this.taskSummary,
    this.runId,
    this.modelTurnId,
  });

  final String id;
  final AgentMessageRole role;
  final String text;
  final DateTime createdAt;
  final List<MessageImage> images;
  final AgentTaskSummary? taskSummary;
  final String? runId;
  final String? modelTurnId;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'images': images.map((image) => image.toJson()).toList(),
    if (taskSummary != null) 'taskSummary': taskSummary!.toJson(),
  };

  factory AgentMessage.fromJson(
    Map<String, Object?> json, {
    required String imageDirectory,
  }) => AgentMessage(
    id: json['id']! as String,
    role: AgentMessageRole.values.byName(json['role']! as String),
    text: json['text']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    taskSummary: json['taskSummary'] == null
        ? null
        : AgentTaskSummary.fromJson(
            (json['taskSummary']! as Map).cast<String, Object?>(),
          ),
    images: (json['images'] as List? ?? const [])
        .map(
          (image) => MessageImage.fromJson(
            (image as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        )
        .toList(),
  );
}

enum AgentStepStatus { running, completed, failed, cancelled }

class AgentStep {
  const AgentStep({
    required this.toolName,
    required this.title,
    required this.status,
    this.detail,
    this.requestJson,
    this.resultJson,
  });

  final String toolName;
  final String title;
  final AgentStepStatus status;
  final String? detail;
  final String? requestJson;
  final String? resultJson;

  AgentStep copyWith({
    AgentStepStatus? status,
    String? detail,
    String? resultJson,
  }) => AgentStep(
    toolName: toolName,
    title: title,
    status: status ?? this.status,
    detail: detail ?? this.detail,
    requestJson: requestJson,
    resultJson: resultJson ?? this.resultJson,
  );
}

class AgentTaskSummary {
  const AgentTaskSummary({
    required this.elapsedMilliseconds,
    this.stopped = false,
    required this.intermediateMessageIds,
    required this.activities,
  });

  final int elapsedMilliseconds;
  final bool stopped;
  final List<String> intermediateMessageIds;
  final List<AgentTaskActivity> activities;

  Map<String, Object?> toJson() => {
    'elapsedMilliseconds': elapsedMilliseconds,
    'stopped': stopped,
    'intermediateMessageIds': intermediateMessageIds,
    'activities': activities.map((activity) => activity.toJson()).toList(),
  };

  factory AgentTaskSummary.fromJson(
    Map<String, Object?> json,
  ) => AgentTaskSummary(
    elapsedMilliseconds: json['elapsedMilliseconds']! as int,
    stopped: json['stopped'] == true,
    intermediateMessageIds: (json['intermediateMessageIds']! as List)
        .cast<String>(),
    activities: (json['activities']! as List)
        .map(
          (item) =>
              AgentTaskActivity.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(),
  );
}

class AgentTaskActivity {
  const AgentTaskActivity({
    required this.text,
    this.status,
    this.requestJson,
    this.resultJson,
  });

  final String text;
  final AgentStepStatus? status;
  final String? requestJson;
  final String? resultJson;

  Map<String, Object?> toJson() => {
    'text': text,
    'status': status?.name,
    if (requestJson != null) 'requestJson': requestJson,
    if (resultJson != null) 'resultJson': resultJson,
  };

  factory AgentTaskActivity.fromJson(Map<String, Object?> json) {
    final status = json['status'] as String?;
    return AgentTaskActivity(
      text: json['text']! as String,
      status: status == null ? null : AgentStepStatus.values.byName(status),
      requestJson: json['requestJson'] as String?,
      resultJson: json['resultJson'] as String?,
    );
  }
}

class AgentRunResult {
  const AgentRunResult({required this.answer, required this.steps});

  final String answer;
  final List<AgentStep> steps;
}

typedef AgentStepListener = void Function(List<AgentStep> steps);

String newMessageId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String toolTitle(String name) => switch (name) {
  'searchConversations' => '搜索历史会话',
  'searchMessages' => '搜索历史消息',
  'readLocalDatabase' => '读取本地记录',
  'getNetworkState' => '检查当前网络',
  'getNetworkEvents' => '读取网络变化记录',
  'dnsLookup' => '解析域名',
  'tlsProbe' => '检查 TLS 连接',
  'httpProbe' => '检查 HTTPS 请求',
  'getNotifications' => '读取通知观察',
  'observeDevice' => '观察当前界面',
  'captureScreen' => '读取当前屏幕',
  'tapScreen' => '点击屏幕位置',
  'wait' => '等待状态变化',
  'requestAccessibilityAccess' => '请求界面操作权限',
  'act' => '操作当前界面',
  'findApps' => '查找应用',
  'launchApp' => '打开应用',
  'startIntent' => '启动 Android 操作',
  'openSettings' => '打开系统设置',
  'shell' => '执行本机命令',
  _ => '执行设备检查',
};
