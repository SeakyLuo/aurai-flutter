import '../domain/tool_customization.dart';
import 'dart:convert';
import 'tool_search.dart';
import 'tool_loader.dart';
import '../domain/capability.dart';
import '../domain/tool_models.dart';

class ToolRegistry {
  ToolRegistry({
    required List<AgentTool> tools,
    required this.capabilities,
    this.groupId,
    this.currentProjectId,
    this.management = false,
  }) : _tools = <String, AgentTool>{
         for (final tool in tools) tool.definition.name: tool,
       } {
    final search = ToolSearch(this);
    _tools[search.definition.name] = search;
    final loader = ToolLoader(this);
    _tools[loader.definition.name] = loader;
  }

  final Map<String, AgentTool> _tools;
  final List<Capability> capabilities;
  final String? groupId;
  final String? Function()? currentProjectId;
  final bool management;
  bool _inScope(String name) =>
      management ||
      ToolCustomizations.availableIn(
        name,
        groupId,
        projectId: currentProjectId?.call(),
      );

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
        .where((tool) => _inScope(tool.definition.name))
        .where(
          (tool) =>
              availableIds.contains(tool.definition.capabilityId) ||
              tool is RuntimeCapabilityAgentTool,
        )
        .map((tool) => ToolCustomizations.apply(tool.definition))
        .toList(growable: false);
  }

  final _loaded = <String>[];
  final _retained = <String>{};
  Set<String> _exposed = {};
  AgentTool? _exclusiveTool;
  AgentTool? _additionalTool;

  List<ToolDefinition> get availableDefinitions => catalog
      .where(
        (tool) =>
            tool.name == 'searchTools' ||
            tool.name == 'loadTools' ||
            tool.name == 'askUser' ||
            tool.name == 'runSubagent' ||
            tool.name == 'runTask' ||
            tool.name == 'hideThinking' ||
            tool.name == 'readInteractiveMessage' ||
            tool.name == 'clickInteractiveMessage' ||
            const [
              'createGoal',
              'clearGoal',
              'createTaskList',
              'getGoal',
              'getTaskList',
              'updateGoal',
              'updateTaskList',
            ].contains(tool.name) ||
            _loaded.contains(tool.name) ||
            _retained.contains(tool.name),
      )
      .toList(growable: false);

  List<ToolDefinition> beginTurn({
    AgentTool? exclusiveTool,
    AgentTool? additionalTool,
  }) {
    _exclusiveTool = exclusiveTool;
    _additionalTool = additionalTool;
    final definitions = exclusiveTool == null
        ? [
            ...availableDefinitions,
            if (additionalTool != null) additionalTool.definition,
          ]
        : [exclusiveTool.definition];
    final scoped = definitions
        .where((tool) => _inScope(tool.name))
        .map(ToolCustomizations.apply)
        .toList();
    _exposed = scoped.map((tool) => tool.name).toSet();
    return scoped;
  }

  bool isExposed(String name) => _exposed.contains(name);

  void load(Iterable<String> names) {
    final available = catalog.map((tool) => tool.name).toSet()
      ..removeAll(['searchTools', 'loadTools', 'askUser']);
    for (final name in names) {
      if (!available.contains(name) || _retained.contains(name)) continue;
      _loaded.remove(name);
      _loaded.add(name);
    }
    if (_loaded.length > 20) _loaded.removeRange(0, _loaded.length - 20);
  }

  /// Restore useful tools, without carrying large historical schemas into every reply.
  /// Explicit tool loading in this run still supplies complete definitions normally.
  void restore(Iterable<String> names) {
    final definitions = {for (final tool in catalog) tool.name: tool};
    final selected = <String>[];
    var remaining = 16000;
    for (final name in names.toList().reversed.toSet()) {
      final tool = definitions[name];
      if (tool == null) continue;
      final size =
          tool.modelDescription.length +
          jsonEncode(tool.modelInputSchema).length;
      if (size > remaining) continue;
      selected.add(name);
      remaining -= size;
      if (selected.length == 20) break;
    }
    load(selected.reversed);
  }

  void retain(String name) {
    if (name == _exclusiveTool?.definition.name) return;
    if (name == _additionalTool?.definition.name) return;
    _loaded.remove(name);
    _retained.add(name);
    // Reading a program exposes the corresponding action entry point too.
    // Catalog/scope checks still decide whether that tool is available.
    if (name == 'readHtmlProgram') {
      _loaded.remove('submitHtmlProgramEvent');
      _retained.add('submitHtmlProgramEvent');
    }
  }

  AgentTool? find(String name) => !_inScope(name)
      ? null
      : _exclusiveTool == null
      ? name == _additionalTool?.definition.name
            ? _additionalTool
            : _tools[name]
      : name == _exclusiveTool!.definition.name
      ? _exclusiveTool
      : null;

  void endTurn() {
    _exclusiveTool = null;
    _additionalTool = null;
    _exposed = {};
  }

  Capability? capabilityFor(AgentTool tool) {
    for (final capability in capabilities) {
      if (capability.id == tool.definition.capabilityId) return capability;
    }
    return null;
  }

  Iterable<AgentTool> get tools => _tools.values;
}
