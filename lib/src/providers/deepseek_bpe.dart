import 'dart:convert';
import 'dart:collection';

/// DeepSeek's published byte-level BPE and sequential pre-tokenizer splits.
/// Counts plaintext; request framing and non-text media are budgeted separately.
class DeepSeekBpe {
  DeepSeekBpe(Map<String, dynamic> definition) {
    final model = definition['model'] as Map;
    final merges = model['merges'] as List;
    for (var i = 0; i < merges.length; i++) {
      ranks[merges[i] as String] = i;
    }
    final stages =
        (definition['pre_tokenizer'] as Map)['pretokenizers'] as List;
    splits = [
      for (final stage in stages.cast<Map>())
        if (stage['type'] == 'Split')
          RegExp((stage['pattern'] as Map)['Regex'] as String, unicode: true),
    ];
    special = RegExp(
      (definition['added_tokens'] as List)
          .cast<Map>()
          .map((t) => RegExp.escape(t['content'] as String))
          .join('|'),
      unicode: true,
    );
    final visible = [
      for (var b = 33; b <= 126; b++) b,
      for (var b = 161; b <= 172; b++) b,
      for (var b = 174; b <= 255; b++) b,
    ];
    var extra = 256;
    bytes = [
      for (var b = 0; b < 256; b++)
        String.fromCharCode(visible.contains(b) ? b : extra++),
    ];
  }
  final ranks = <String, int>{};
  late final List<RegExp> splits;
  late final RegExp special;
  late final List<String> bytes;
  final _cache = LinkedHashMap<String, int>();

  int count(String text) {
    var count = 0, offset = 0;
    for (final match in special.allMatches(text)) {
      count += _plain(text.substring(offset, match.start)) + 1;
      offset = match.end;
    }
    return count + _plain(text.substring(offset));
  }

  int _plain(String text) {
    var pieces = [text];
    for (final pattern in splits) {
      final next = <String>[];
      for (final piece in pieces) {
        var start = 0;
        for (final match in pattern.allMatches(piece)) {
          if (match.start > start)
            next.add(piece.substring(start, match.start));
          next.add(match.group(0)!);
          start = match.end;
        }
        if (start < piece.length) next.add(piece.substring(start));
      }
      pieces = next;
    }
    var result = 0;
    for (final piece in pieces) {
      final cached = _cache[piece];
      if (cached != null) {
        result += cached;
        continue;
      }
      final count = _merge(utf8.encode(piece).map((b) => bytes[b]).toList());
      result += count;
      // Do not retain long transcripts or grow the cache with every chat.
      if (piece.length <= 128) {
        _cache[piece] = count;
        if (_cache.length > 8192) _cache.remove(_cache.keys.first);
      }
    }
    return result;
  }

  int _merge(List<String> tokens) {
    if (tokens.length < 2) return tokens.length;
    final next = List.generate(tokens.length, (i) => i + 1);
    final previous = List.generate(tokens.length, (i) => i - 1);
    final versions = List.filled(tokens.length, 0);
    final heap = _MergeHeap();
    void offer(int left) {
      if (left < 0 || next[left] >= tokens.length) return;
      final right = next[left];
      final rank = ranks['${tokens[left]} ${tokens[right]}'];
      if (rank != null)
        heap.add((
          rank: rank,
          left: left,
          right: right,
          version: versions[left],
          rightVersion: versions[right],
        ));
    }

    for (var i = 0; i < tokens.length - 1; i++) offer(i);
    var count = tokens.length;
    while (heap.items.isNotEmpty) {
      final edge = heap.remove();
      final left = edge.left, right = edge.right;
      if (versions[left] != edge.version ||
          versions[right] != edge.rightVersion ||
          next[left] != right)
        continue;
      tokens[left] += tokens[right];
      versions[left]++;
      versions[right]++;
      next[left] = next[right];
      if (next[right] < tokens.length) previous[next[right]] = left;
      next[right] = tokens.length;
      count--;
      offer(previous[left]);
      offer(left);
    }
    return count;
  }
}

typedef _Edge = ({
  int rank,
  int left,
  int right,
  int version,
  int rightVersion,
});

class _MergeHeap {
  final items = <_Edge>[];
  bool before(_Edge a, _Edge b) =>
      a.rank < b.rank || (a.rank == b.rank && a.left < b.left);
  void add(_Edge value) {
    items.add(value);
    var i = items.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (!before(value, items[parent])) break;
      items[i] = items[parent];
      i = parent;
    }
    items[i] = value;
  }

  _Edge remove() {
    final result = items.first, last = items.removeLast();
    if (items.isEmpty) return result;
    var i = 0;
    while (i * 2 + 1 < items.length) {
      var child = i * 2 + 1;
      if (child + 1 < items.length && before(items[child + 1], items[child]))
        child++;
      if (!before(items[child], last)) break;
      items[i] = items[child];
      i = child;
    }
    items[i] = last;
    return result;
  }
}
