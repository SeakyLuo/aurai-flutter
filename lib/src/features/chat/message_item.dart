import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/agent_models.dart';
import '../../platform/aurai_platform.dart';

class MessageItem extends StatefulWidget {
  const MessageItem({super.key, required this.message});
  final AgentMessage message;

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  AgentMessage get message => widget.message;
  late Widget _content;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _content = _buildContent(context);
  }

  @override
  void didUpdateWidget(MessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != message) _content = _buildContent(context);
  }

  @override
  Widget build(BuildContext context) => message.role == AgentMessageRole.user
      ? _content
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _content,
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        tooltip: '复制回复',
                        onPressed: () => _copy(context),
                        icon: const Icon(
                          Icons.copy_outlined,
                          size: 21,
                          color: Color(0xff8b8b8b),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: _fullTime,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Text(
                          _displayTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff94989f),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

  Widget _buildContent(BuildContext context) {
    if (message.role == AgentMessageRole.user) {
      return LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth - 32) * 0.82,
            ),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xffe7f3ff),
              borderRadius: BorderRadius.circular(26),
            ),
            child: SelectableText(
              message.text,
              style: const TextStyle(
                color: Color(0xff153c60),
                fontSize: 17,
                height: 1.55,
              ),
            ),
          ),
        ),
      );
    }
    const body = TextStyle(
      color: Color(0xff171717),
      fontSize: 17,
      height: 1.65,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: message.text,
            selectable: true,
            fitContent: false,
            onTapLink: (text, href, title) => _openLink(context, href),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: body,
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  h1: body.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  h2: body.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  h3: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  h1Padding: const EdgeInsets.only(top: 12),
                  h2Padding: const EdgeInsets.only(top: 12),
                  h3Padding: const EdgeInsets.only(top: 8),
                  blockSpacing: 20,
                  listIndent: 24,
                  listBullet: body,
                  blockquote: body,
                  blockquotePadding: const EdgeInsets.only(
                    left: 18,
                    top: 2,
                    bottom: 2,
                  ),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xffcdcdcd), width: 3),
                    ),
                  ),
                  code: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xff303030),
                    backgroundColor: Color(0xfff3f3f3),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xfff6f6f6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  codeblockPadding: const EdgeInsets.all(16),
                  tableColumnWidth: const IntrinsicColumnWidth(),
                  tableBody: body.copyWith(fontSize: 15),
                  tableHead: body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  tableCellsPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  tableBorder: TableBorder.all(color: const Color(0xffe4e4e4)),
                  a: body.copyWith(
                    color: const Color(0xff087cf0),
                    decoration: TextDecoration.underline,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String get _displayTime {
    final date = message.createdAt.toLocal();
    final now = DateTime.now();
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (date.year == now.year && date.month == now.month && date.day == now.day)
      return time;
    return '${date.year == now.year ? '' : '${date.year}年'}${date.month}月${date.day}日 $time';
  }

  String get _fullTime {
    final date = message.createdAt.toLocal();
    return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (context.mounted) _notice(context, '回复已复制');
    } on Object {
      if (context.mounted) _notice(context, '复制失败，请重试');
    }
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      _notice(context, '无法打开此链接');
      return;
    }
    try {
      await AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': uri.toString(),
      });
    } on Object {
      if (context.mounted) _notice(context, '无法打开链接，请稍后再试');
    }
  }

  void _notice(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
