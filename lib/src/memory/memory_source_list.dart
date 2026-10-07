import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/glass_notice.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../domain/message_sender.dart';
import 'memory_controller.dart';
import 'memory_toast.dart';

typedef OpenMemorySource = Future<void> Function(Map<String, Object?> source);

class MemorySourceList extends StatefulWidget {
  const MemorySourceList({
    super.key,
    required this.memory,
    required this.entry,
    this.onOpen,
  });
  final MemoryController memory;
  final Map<String, Object?> entry;
  final OpenMemorySource? onOpen;

  @override
  State<MemorySourceList> createState() => _MemorySourceListState();
}

class _MemorySourceListState extends State<MemorySourceList> {
  static const _itemGap = SizedBox(height: 24);

  TextStyle get _labelStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  final _sources = <Map<String, Object?>>[];
  bool _loading = true, _more = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.memory.sources(
        widget.entry['id'] as String,
        offset: _sources.length,
        management: true,
      );
      if (!mounted) return;
      setState(() {
        _sources.addAll(rows.take(20));
        _more = rows.length > 20;
      });
    } on Object catch (error) {
      _failed = true;
      if (mounted)
        memoryToast(context, error.toString(), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, Object?> source) async {
    try {
      await widget.onOpen!(source);
    } on Object catch (error) {
      if (mounted)
        memoryToast(context, error.toString(), kind: ToastKind.error);
    }
  }

  Widget _sourceTile(Map<String, Object?> source) {
    final available = source['available'] == true;
    final canOpen = available && widget.onOpen != null;
    final createdAt = source['message_created_at'] as int?;
    final senderRow = source['sender'] as Map<String, Object?>?;
    final sender = senderRow == null ? null : MessageSender.fromRow(senderRow);
    final text = source['message_text'] as String?;
    final colors = Theme.of(context).colorScheme;
    final secondaryStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: colors.onSurfaceVariant,
    );
    final label = !available
        ? '原始记录已删除'
        : source['tool_call_id'] != null
        ? '工具执行过程'
        : source['message_id'] != null
        ? '原始消息'
        : '任务执行记录';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? () => _open(source) : null,
          child: Container(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colors.outlineVariant, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (sender != null) ...[
                      MemberAvatar(sender: sender, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        sender?.displayName ?? label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(_sourceTime(createdAt), style: secondaryStyle),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        !available
                            ? '原始记录已删除'
                            : text != null && text.trim().isNotEmpty
                            ? text.replaceAll(RegExp(r'\s+'), ' ').trim()
                            : source['tool_call_id'] != null
                            ? '工具执行：${source['tool_title']}'
                            : label,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (source['title'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 16,
                        child: FittedBox(
                          child:
                              source['conversation_kind'] != 'group' &&
                                  source['personal_chat'] != 1
                              ? SettingsIcon(
                                  type: SettingsIconType.job,
                                  color: colors.onSurfaceVariant,
                                )
                              : ConversationMenuIcon(
                                  type: source['conversation_kind'] == 'group'
                                      ? ConversationMenuIconType.members
                                      : ConversationMenuIconType.profile,
                                  color: colors.onSurfaceVariant,
                                ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          source['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: secondaryStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sourceTime(int microseconds) {
    final time = DateTime.fromMicrosecondsSinceEpoch(microseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    final year = time.year == DateTime.now().year ? '' : '${time.year}/';
    return '$year${two(time.month)}/${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  Widget _propertyRow(String label, String value, {String? description}) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(color: colors.onSurface, height: 1.5),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = Theme.of(context).colorScheme;
    final isExperience = entry['kind'] == 'experience';
    final keywords = (jsonDecode(entry['keywords_json'] as String) as List)
        .cast<String>();
    final assertion = switch (entry['assertion']) {
      'observed' => '根据实际观察或工具结果记录',
      'inferred' => '根据已有信息推测得出',
      'dream' => '根据梦境内容记录',
      _ => '根据对话中的陈述记录',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _itemGap,
        _propertyRow(
          '类型',
          isExperience ? '经验' : '记忆',
          description: isExperience ? '记录做事的方法、经验与适用条件' : '记录事实、偏好与事件',
        ),
        _itemGap,
        _propertyRow('依据', assertion),
        if (keywords.isNotEmpty) ...[
          _itemGap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Text('标签', style: _labelStyle),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final keyword in keywords)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: settingsFieldColor(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          keyword,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        _itemGap,
        Text('来源', style: _labelStyle),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_sources.isEmpty && !_failed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('手动保存，未关联原始记录'),
          ),
        for (final source in _sources) _sourceTile(source),
        if (_more && !_loading)
          TextButton(
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            child: const Text('更多来源'),
          ),
      ],
    );
  }
}
