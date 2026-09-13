/// Consecutive calls to the same tool share a display group; null is a boundary.
List<({int start, int end})> toolActivityGroups(List<String?> tools) {
  final groups = <({int start, int end})>[];
  var start = 0;
  while (start < tools.length) {
    var end = start + 1;
    final tool = tools[start];
    if (tool != null && tool != 'askUser') {
      while (end < tools.length && tools[end] == tool) {
        end++;
      }
    }
    groups.add((start: start, end: end));
    start = end;
  }
  return groups;
}
