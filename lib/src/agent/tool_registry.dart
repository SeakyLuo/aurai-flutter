import '../domain/capability.dart';
import '../domain/tool_models.dart';

class ToolRegistry {
  ToolRegistry({required List<AgentTool> tools, required this.capabilities})
    : _tools = <String, AgentTool>{
        for (final tool in tools) tool.definition.name: tool,
      };

  final Map<String, AgentTool> _tools;
  final List<Capability> capabilities;

  List<ToolDefinition> get availableDefinitions {
    final availableIds = capabilities
        .where(
          (capability) =>
              capability.availability == CapabilityAvailability.available ||
              capability.availability ==
                  CapabilityAvailability.permissionRequired,
        )
        .map((capability) => capability.id)
        .toSet();
    return _tools.values
        .where(
          (tool) =>
              availableIds.contains(tool.definition.capabilityId) ||
              tool is RuntimeCapabilityAgentTool,
        )
        .map((tool) => tool.definition)
        .toList(growable: false);
  }

  AgentTool? find(String name) => _tools[name];

  Capability? capabilityFor(AgentTool tool) {
    for (final capability in capabilities) {
      if (capability.id == tool.definition.capabilityId) return capability;
    }
    return null;
  }

  Iterable<AgentTool> get tools => _tools.values;
}
