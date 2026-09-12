class ContextSummary {
  const ContextSummary({required this.text, required this.throughMessageId});

  final String text;
  final String throughMessageId;

  Map<String, Object?> toJson() => {
    'text': text,
    'throughMessageId': throughMessageId,
  };

  factory ContextSummary.fromJson(Map<String, Object?> json) => ContextSummary(
    text: json['text']! as String,
    throughMessageId: json['throughMessageId']! as String,
  );
}
