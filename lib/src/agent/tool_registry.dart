import '../domain/tool_customization.dart';
import 'tool_search.dart';
import '../domain/capability.dart';
import '../domain/tool_models.dart';

class ToolRegistry {
  ToolRegistry({required List<AgentTool> tools, required this.capabilities})
    : _tools = <String, AgentTool>{
        for (final tool in tools) tool.definition.name: tool,
      } {
    final search = ToolSearch(this);
    _tools[search.definition.name] = search;
  }

  final Map<String, AgentTool> _tools;
  final List<Capability> capabilities;

  List<ToolDefinition> get catalog {
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
        .map((tool) => ToolCustomizations.apply(tool.definition))
        .toList(growable: false);
  }

  final _loaded = <String>[];
  Set<String> _exposed = {};

  List<ToolDefinition> get availableDefinitions => catalog
      .where(
        (tool) =>
            tool.name == 'searchTools' ||
            tool.name == 'askUser' ||
            _loaded.contains(tool.name),
      )
      .toList(growable: false);

  List<ToolDefinition> beginTurn() {
    final definitions = availableDefinitions;
    _exposed = definitions.map((tool) => tool.name).toSet();
    return definitions;
  }

  bool isExposed(String name) => _exposed.contains(name);

  void load(Iterable<String> names) {
    final available = catalog.map((tool) => tool.name).toSet()
      ..removeAll(['searchTools', 'askUser']);
    for (final name in names) {
      if (!available.contains(name)) continue;
      _loaded.remove(name);
      _loaded.add(name);
    }
    if (_loaded.length > 20) _loaded.removeRange(0, _loaded.length - 20);
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
