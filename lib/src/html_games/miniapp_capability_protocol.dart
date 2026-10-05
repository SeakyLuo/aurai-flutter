import 'dart:convert';

/// The declaration grants access to a host API, not authority over other users.
abstract final class MiniappCapabilityProtocol {
  static const operations = {
    'messages.send',
    'messages.intercept',
    'cards.close',
    'cards.submit',
    'replies.set',
    'replies.release',
    'members.rename',
    'timer.set',
    'context.compact',
  };
  static final _manifest = RegExp(
    r'<script\s+type="application/json"\s+id="aurai-capabilities">([\s\S]*?)</script>',
  );

  static Set<String> declarations(String html) {
    final match = _manifest.firstMatch(html);
    if (match == null) throw ArgumentError('小程序必须声明 aurai-capabilities');
    final names = (jsonDecode(match.group(1)!) as List).cast<String>();
    for (final name in names) {
      if (!operations.contains(name)) throw ArgumentError('不支持的小程序能力：$name');
    }
    return names.toSet();
  }

  static String wrap(String source, Set<String> declared) =>
      '''
const __effects = [];
const __allowed = ${jsonEncode(declared.toList())};
const __host = Object.freeze({call: function(name, args) {
  if (__allowed.indexOf(name) < 0) throw new Error('Undeclared capability: ' + name);
  if (__effects.length >= 128) throw new Error('Too many capability calls');
  __effects.push({name: name, args: JSON.parse(JSON.stringify(args))});
}});
const __result = (function(ctx, host) {
$source
})(ctx, __host);
Object.keys(__result).forEach(function(key) {
  if (['state', 'view', 'privateViews'].indexOf(key) < 0)
    throw new Error('Unsupported reducer output: ' + key);
});
return {state: __result.state, view: __result.view,
  privateViews: __result.privateViews, effects: __effects};
''';
}

/// Validates the untrusted runtime output before any host operation is applied.
class MiniappCapabilityCalls {
  MiniappCapabilityCalls(Map<String, Object?> output, Set<String> declared) {
    final calls = output['effects'] as List;
    if (calls.length > 128) throw ArgumentError('单次事件最多调用 128 次能力');
    final singleton = <String>{};
    for (final raw in calls) {
      final call = raw as Map;
      final name = call['name'] as String;
      if (!declared.contains(name) ||
          !MiniappCapabilityProtocol.operations.contains(name)) {
        throw ArgumentError('小程序调用了未声明的能力：$name');
      }
      final args = (call['args'] as Map).cast<String, Object?>();
      if (name != 'messages.send' &&
          name != 'cards.close' &&
          !singleton.add(name)) {
        throw ArgumentError('单次事件不能重复调用：$name');
      }
      switch (name) {
        case 'messages.send':
          messages.add(args);
        case 'messages.intercept':
          final action = args['action'] as String;
          if (action.isEmpty) throw ArgumentError('消息拦截需要处理事件');
          for (final actor in (args['actors'] as List).cast<String>()) {
            messageRoutes[actor] = action;
          }
        case 'cards.close':
          closeKeys.addAll((args['keys'] as List).cast<String>());
        case 'cards.submit':
          submissions.add(args);
        case 'replies.set':
          replyStates.addAll((args['states'] as Map).cast<String, bool>());
        case 'replies.release':
          releaseReplies = true;
        case 'members.rename':
          nicknames.addAll((args['names'] as Map).cast<String, String>());
        case 'timer.set':
          if (!args.containsKey('at')) throw ArgumentError('timer.set 必须提供 at');
          timerChanged = true;
          wakeAt = args['at'] as int?;
        case 'context.compact':
          final instructions = args['instructions'] as String? ?? '';
          if (instructions.length > 4000) {
            throw ArgumentError('额外压缩要求不能超过 4000 字');
          }
          if (args.keys.any((key) => key != 'instructions')) {
            throw ArgumentError('context.compact 只支持 instructions 参数');
          }
          contextInstructions = instructions;
      }
    }
    if (messages.length > 64) throw ArgumentError('单次事件最多产生 64 条消息');
    if (releaseReplies && replyStates.isNotEmpty) {
      throw ArgumentError('同一事件不能同时设置和释放接话控制');
    }
  }

  final messages = <Map<String, Object?>>[];
  final messageRoutes = <String, String>{};
  final closeKeys = <String>{};
  final submissions = <Map<String, Object?>>[];
  final replyStates = <String, bool>{};
  final nicknames = <String, String>{};
  bool releaseReplies = false;
  bool timerChanged = false;
  int? wakeAt;
  String? contextInstructions;
}
