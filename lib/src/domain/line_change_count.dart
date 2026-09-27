import 'dart:typed_data';

typedef LineChangeCount = ({int added, int removed});

/// Myers shortest edit distance, bounded so unrelated large files cannot stall UI.
LineChangeCount? countLineChanges(List<String> before, List<String> after) {
  var start = 0;
  var oldEnd = before.length;
  var newEnd = after.length;
  while (start < oldEnd && start < newEnd && before[start] == after[start]) {
    start++;
  }
  while (oldEnd > start &&
      newEnd > start &&
      before[oldEnd - 1] == after[newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }
  final n = oldEnd - start;
  final m = newEnd - start;
  if (n == 0 || m == 0) return (added: m, removed: n);
  // With no shared lines the exact answer needs no diff traversal.
  final oldLines = before.sublist(start, oldEnd).toSet();
  if (!after.skip(start).take(m).any(oldLines.contains))
    return (added: m, removed: n);
  final maximum = n + m;
  final offset = maximum + 1;
  final frontier = Int32List(2 * maximum + 3);
  var remaining = 250000;
  for (var distance = 0; distance <= maximum; distance++) {
    for (var diagonal = -distance; diagonal <= distance; diagonal += 2) {
      if (--remaining < 0) return null;
      final index = offset + diagonal;
      var x =
          diagonal == -distance ||
              (diagonal != distance &&
                  frontier[index - 1] < frontier[index + 1])
          ? frontier[index + 1]
          : frontier[index - 1] + 1;
      var y = x - diagonal;
      while (x < n && y < m && before[start + x] == after[start + y]) {
        if (--remaining < 0) return null;
        x++;
        y++;
      }
      frontier[index] = x;
      if (x >= n && y >= m) {
        return (
          added: (distance + m - n) ~/ 2,
          removed: (distance + n - m) ~/ 2,
        );
      }
    }
  }
  throw StateError('Line diff did not reach the end');
}
