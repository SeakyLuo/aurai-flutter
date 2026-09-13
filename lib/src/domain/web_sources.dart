import 'dart:convert';

import 'agent_models.dart';
import 'source_reference.dart';

// Completed tool records are immutable; reuse parsed sources during streaming.
final _cachedSources = Expando<List<SourceReference>>();

Map<String, SourceReference> webSourcesFromSteps(Iterable<AgentStep> steps) => {
  for (final step in steps)
    if (step.status == AgentStepStatus.completed)
      for (final source in _sources(step, step.toolName, step.resultJson))
        source.url: source,
};

Map<String, SourceReference> webSourcesFromActivities(
  Iterable<AgentTaskActivity> activities,
) => {
  for (final activity in activities)
    if (activity.status == AgentStepStatus.completed)
      for (final source in _sources(
        activity,
        activity.toolName,
        activity.resultJson,
      ))
        source.url: source,
};

List<SourceReference> _sources(Object record, String? tool, String? result) {
  if (!{
    'searchWeb',
    'readWebPage',
    'setSourceDates',
    'readDocument',
  }.contains(tool))
    return const [];
  if (result == null) return const [];
  return _cachedSources[record] ??= _read(tool!, result);
}

List<SourceReference> _read(String tool, String result) {
  final output = jsonDecode(result) as Map<String, dynamic>;
  if (tool == 'readDocument' && output['sourceRead'] != true) return const [];
  final entries = tool != 'readWebPage' && tool != 'readDocument'
      ? (output['results'] as List).cast<Map>()
      : [output];
  return [
    for (final entry in entries)
      SourceReference(
        title: entry['title'] as String,
        url: entry['url'] as String,
        siteName: entry['siteName'] as String?,
        publishedAt: entry['publishedAt'] as String?,
      ),
  ];
}
