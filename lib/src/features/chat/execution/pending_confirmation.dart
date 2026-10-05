import 'dart:async';

import '../../../domain/tool_models.dart';

class PendingConfirmation {
  PendingConfirmation(
    this.call,
    this.definition,
    this.conversationId,
    this.senderId,
    this.senderName,
    this.label,
  ) : deadline = call.confirmationTimeoutSeconds == null
          ? null
          : DateTime.now().add(
              Duration(seconds: call.confirmationTimeoutSeconds!),
            );
  final String conversationId;
  final String senderId;
  final String senderName;
  final String label;
  final DateTime? deadline;
  final ToolCall call;
  final ToolDefinition definition;
  String scope = 'once';
  final completer = Completer<bool>();
}
