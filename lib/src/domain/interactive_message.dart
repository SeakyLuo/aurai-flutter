class InteractiveMessage {
  const InteractiveMessage({
    required this.revision,
    required this.title,
    required this.body,
    required this.buttons,
    this.states = const [],
  });
  final int revision;
  final List<Map<String, Object?>> states;
  final String title;
  final String body;
  final List<Map<String, Object?>> buttons;

  factory InteractiveMessage.fromJson(Map<String, Object?> json) {
    final title = json['title'] as String;
    final body = json['body'] as String;
    final buttons = (json['buttons'] as List)
        .map((b) => Map<String, Object?>.from(b as Map))
        .toList();
    if (title.trim().isEmpty ||
        title.length > 100 ||
        body.length > 10000 ||
        buttons.isEmpty ||
        buttons.length > 12) {
      throw ArgumentError('请提供标题、最多 10000 字正文和 1–12 个按钮');
    }
    final states = (json['states'] as List? ?? const [])
        .map((state) => Map<String, Object?>.from(state as Map))
        .toList();
    if (states.length > 16) throw ArgumentError('最多 16 个卡片状态');
    final stateIds = <String>{};
    for (final state in states) {
      final id = state['id'];
      if (id is! String || id.isEmpty || !stateIds.add(id))
        throw ArgumentError('状态标识必须非空且唯一');
    }
    _validateButtons(buttons, stateIds);
    for (final state in states) {
      final stateTitle = state['title'] as String;
      final stateBody = state['body'] as String;
      final stateButtons = (state['buttons'] as List)
          .map((b) => Map<String, Object?>.from(b as Map))
          .toList();
      if (stateTitle.trim().isEmpty ||
          stateTitle.length > 100 ||
          stateBody.length > 10000 ||
          stateButtons.isEmpty ||
          stateButtons.length > 12)
        throw ArgumentError('每个状态需要标题、最多 10000 字正文和 1–12 个按钮');
      _validateButtons(stateButtons, stateIds);
    }
    return InteractiveMessage(
      revision: json['revision'] as int,
      title: title,
      body: body,
      buttons: buttons,
      states: states,
    );
  }

  static void _validateButtons(
    List<Map<String, Object?>> buttons,
    Set<String> stateIds,
  ) {
    final ids = <String>{};
    for (final b in buttons) {
      if (!ids.add(b['id'] as String) ||
          (b['id'] as String).isEmpty ||
          (b['label'] as String).trim().isEmpty ||
          (b['label'] as String).length > 80 ||
          !['update', 'acknowledge', 'openUrl'].contains(b['action']) ||
          b['repeatable'] is! bool) {
        throw ArgumentError('按钮标识需唯一，文字不能为空，动作需有效');
      }
      if (b['completedLabel'] != null &&
          (b['completedLabel'] is! String ||
              (b['completedLabel'] as String).trim().isEmpty ||
              (b['completedLabel'] as String).length > 80))
        throw ArgumentError('完成后的按钮文字需为 1–80 字');
      if (b['notifyAi'] != null && b['notifyAi'] is! bool)
        throw ArgumentError('notifyAi 必须是布尔值');
      if (b['disabled'] != null && b['disabled'] is! bool)
        throw ArgumentError('按钮禁用状态必须为布尔值');
      if (b['style'] != null &&
          ![
            'normal',
            'primary',
            'info',
            'warning',
            'danger',
            'success',
          ].contains(b['style']))
        throw ArgumentError('不支持的按钮样式');
      if (b['icon'] != null &&
          ![
            'none',
            'info',
            'play',
            'reset',
            'delete',
            'check',
            'open',
            'settings',
          ].contains(b['icon']))
        throw ArgumentError('不支持的按钮图标');
      if (b['showArrow'] != null && b['showArrow'] is! bool)
        throw ArgumentError('箭头参数必须为布尔值');
      if (b['action'] == 'openUrl') {
        final uri = Uri.tryParse(b['url'] as String? ?? '');
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw ArgumentError('按钮链接必须是完整 HTTPS 地址');
        }
      }
      if (b['nextBody'] is String && (b['nextBody'] as String).length > 10000)
        throw ArgumentError('更新正文最多 10000 字');
      if (b['nextState'] != null && !stateIds.contains(b['nextState']))
        throw ArgumentError('nextState 必须指向已定义的状态');
      if (b['action'] == 'update' &&
          ((b['nextBody'] is String) == (b['nextState'] is String))) {
        throw ArgumentError('更新按钮需要 nextBody 或 nextState，二选一');
      }
    }
  }

  Map<String, Object?> toJson() => {
    'revision': revision,
    'title': title,
    'body': body,
    'buttons': buttons,
    if (states.isNotEmpty) 'states': states,
  };
}
