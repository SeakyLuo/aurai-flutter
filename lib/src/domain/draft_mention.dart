class DraftMention {
  DraftMention(this.start, this.text, this.senderId);
  int start;
  final String text;
  final String? senderId;
  Map<String, Object?> toJson() => {
    'start': start,
    'text': text,
    'senderId': senderId,
  };
  factory DraftMention.fromJson(Map<String, dynamic> value) => DraftMention(
    value['start'] as int,
    value['text'] as String,
    value['senderId'] as String?,
  );
}
