enum AgentMessageRole { user, assistant }

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final AgentMessageRole role;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AgentMessage.fromJson(Map<String, Object?> json) => AgentMessage(
    id: json['id']! as String,
    role: AgentMessageRole.values.byName(json['role']! as String),
    text: json['text']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

enum AgentStepStatus { running, completed, failed, cancelled }

class AgentStep {
  const AgentStep({
    required this.toolName,
    required this.title,
    required this.status,
    this.detail,
  });

  final String toolName;
  final String title;
  final AgentStepStatus status;
  final String? detail;

  AgentStep copyWith({AgentStepStatus? status, String? detail}) => AgentStep(
    toolName: toolName,
    title: title,
    status: status ?? this.status,
    detail: detail ?? this.detail,
  );
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
