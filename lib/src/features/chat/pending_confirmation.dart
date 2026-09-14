part of 'chat_controller.dart';

class PendingConfirmation {
  PendingConfirmation(this.call, this.definition, this.conversationId)
    : deadline = call.confirmationTimeoutSeconds == null
          ? null
          : DateTime.now().add(
              Duration(seconds: call.confirmationTimeoutSeconds!),
            );
  final String conversationId;
  final DateTime? deadline;
  final ToolCall call;
  final ToolDefinition definition;
  String scope = 'once';
  final completer = Completer<bool>();
}
