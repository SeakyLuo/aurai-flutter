import 'agent_models.dart';
import 'interactive_message.dart';
import 'message_summary.dart';

class MessageQuote {
  MessageQuote({
    required this.messageId,
    required String senderId,
    required String text,
    List<String>? audience,
    List<String>? excludedAudience,
    bool markdown = true,
    this.excerpt = false,
  }) : _senderId = senderId,
       _text = MessageSummary.preview(text, limit: 1000),
       _audience = audience,
       _excludedAudience = excludedAudience,
       _markdown = markdown;
  final String messageId;
  final bool excerpt;
  final String _senderId, _text;
  final bool _markdown;
  final List<String>? _audience, _excludedAudience;
  late String _senderName;
  AgentMessage? _source;
  InteractiveMessage? _card;

  void resolveSource(AgentMessage message) {
    _source = message;
    _card = message.interactive;
  }

  void resolveCard(InteractiveMessage card) => _card = card;

  String get senderId => _source?.senderId ?? _senderId;
  String get senderName => _source?.sender?.name ?? _senderName;
  set senderName(String name) => _senderName = name;
  List<String>? get audience => _card != null
      ? (_card!.participation['audience'] as List?)?.cast<String>()
      : _source != null
      ? _source!.audience
      : _audience;
  List<String>? get excludedAudience => _card != null
      ? (_card!.participation['excludedAudience'] as List?)?.cast<String>()
      : _source != null
      ? _source!.excludedAudience
      : _excludedAudience;
  bool get markdown => _source != null && !excerpt
      ? _source!.role == AgentMessageRole.assistant &&
            (!_source!.isGroupMessage || _source!.markdown)
      : _markdown;
  List<String> get questions => !excerpt && _card?.isQuestion == true
      ? [
          for (final button in _card!.buttons)
            if (button['questions'] case final List questions)
              for (final question in questions) question['question'] as String
            else if (button['selection'] != null)
              _card!.title,
        ]
      : const [];
  String get text {
    if (excerpt) return _text;
    if (_card != null) {
      if (questions.isNotEmpty) return questions.join('\n');
      return '[${_card!.isVote ? '投票' : '交互消息'}] ${_card!.title}';
    }
    return _source == null ? _text : MessageSummary.fromMessage(_source!);
  }

  bool canView(String viewer) =>
      (audience == null || audience!.contains(viewer)) &&
      !(excludedAudience?.contains(viewer) ?? false);
  String textFor(String viewer) => canView(viewer) ? text : '你没有查看这条消息的权限';
  // Resolved content is transient; only the small creation snapshot is stored.
  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'senderId': _senderId,
    'text': _text,
    'markdown': _markdown,
    'excerpt': excerpt,
    if (_audience != null) 'audience': _audience,
    if (_excludedAudience != null) 'excludedAudience': _excludedAudience,
  };
  factory MessageQuote.fromJson(Map<String, Object?> json) => MessageQuote(
    messageId: json['messageId'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
    markdown: json['markdown'] != false,
    excerpt: json['excerpt'] == true,
    audience: (json['audience'] as List?)?.cast<String>(),
    excludedAudience: (json['excludedAudience'] as List?)?.cast<String>(),
  );
}
