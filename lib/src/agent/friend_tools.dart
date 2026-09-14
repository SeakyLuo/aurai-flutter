import '../domain/tool_models.dart';
import '../storage/contact_relationships.dart';

class FriendTool implements AgentTool, RuntimeCapabilityAgentTool {
  FriendTool(this.store, this.ownerId, this.name, this.changed);
  final ContactRelationships store;
  final String ownerId;
  final String name;
  final void Function() changed;
  static const names = ['findContacts', 'listFriends', 'addFriend'];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.ai_contacts',
    safety: name == 'addFriend' ? ToolSafety.lowRisk : ToolSafety.readOnly,
    description: switch (name) {
      'findContacts' =>
        'Find existing people and AI contacts by name. Returns public identity, not private instructions. Discover a contact here or from a group roster before adding a friend.',
      'listFriends' =>
        'List your own friends, including humans and AIs, with name search and offset pagination. This is your address book, not the human user address book.',
      _ =>
        'Add an existing contact as your friend, establishing a mutual relationship. Does not send any message. Then createConversation with contactId and sendConversationMessage in that conversation to chat. Act naturally within the user-approved activity; do not add unrelated contacts.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'addFriend') 'contactId': {'type': 'string'},
        if (name != 'addFriend') ...{
          'query': {'type': 'string'},
          'offset': {'type': 'integer', 'minimum': 0},
        },
      },
      'required': name == 'addFriend' ? ['contactId'] : ['query', 'offset'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final Map<String, Object?> output;
      if (name == 'addFriend') {
        await store.add(ownerId, call.arguments['contactId'] as String);
        changed();
        output = {'added': true, 'contactId': call.arguments['contactId']};
      } else {
        final offset = call.arguments['offset'] as int;
        final rows = await store.list(
          ownerId,
          call.arguments['query'] as String,
          offset,
          discover: name == 'findContacts',
        );
        output = {
          'contacts': rows.take(50).toList(),
          'hasMore': rows.length > 50,
          if (rows.length > 50) 'nextOffset': offset + 50,
        };
      }
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
