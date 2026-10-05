import '../domain/tool_models.dart';

/// Children may use execution tools; conversation publishing and durable
/// account/agent configuration remain with the delegating agent.
bool availableToSubagent(AgentTool tool) {
  final definition = tool.definition;
  if (definition.name == 'askUser') return true;
  if (const {
    'task.manage',
    'runtime.subagent',
    'android.scheduled_tasks',
  }.contains(definition.capabilityId))
    return false;
  if (const {
    'local.app',
    'model.settings',
    'model.topUp',
    'local.ai_contacts',
    'local.messages',
    'local.group_chats',
    'memory.manage',
    'skills',
  }.contains(definition.capabilityId)) {
    return definition.safety == ToolSafety.readOnly &&
        definition.actionSafety.values.every(
          (safety) => safety == ToolSafety.readOnly,
        );
  }
  if (const {
    'deliverFile',
    'recallMessage',
    'sendNotification',
  }.contains(definition.name))
    return false;
  return true;
}
