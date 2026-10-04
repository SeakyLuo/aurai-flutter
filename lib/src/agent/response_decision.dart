/// A program-owned decision request, separate from ordinary assistant replies.
class ResponseDecision {
  const ResponseDecision({
    required this.instructions,
    required this.schema,
    required this.submit,
  });

  final String instructions;
  final Map<String, Object?> schema;
  final Future<void> Function(String response) submit;
}
