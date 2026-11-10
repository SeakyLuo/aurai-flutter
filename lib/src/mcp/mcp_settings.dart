import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class McpConnection {
  const McpConnection({
    required this.id,
    required this.name,
    required this.url,
    required this.token,
    required this.enabled,
  });
  final String id, name, url, token;
  final bool enabled;
  factory McpConnection.create() => McpConnection(
    id: List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(),
    name: '',
    url: '',
    token: '',
    enabled: true,
  );
  factory McpConnection.fromJson(Map json) => McpConnection(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    token: json['token'] as String,
    enabled: json['enabled'] as bool,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'token': token,
    'enabled': enabled,
  };
  McpConnection withEnabled(bool value) =>
      McpConnection(id: id, name: name, url: url, token: token, enabled: value);
  void validate() {
    if (name.trim().isEmpty) throw ArgumentError('请填写连接名称');
    final uri = Uri.parse(url);
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme)) {
      throw ArgumentError('请填写完整的 HTTP 或 HTTPS MCP 地址');
    }
  }
}

class McpSettings extends ChangeNotifier {
  McpSettings._();
  static final instance = McpSettings._();
  final _preferences = SharedPreferencesAsync();
  final List<McpConnection> _connections = [];
  List<McpConnection> get connections => List.unmodifiable(_connections);
  Future<void>? _loading;
  bool _loaded = false;
  Future<void> _pending = Future.value();
  Future<void> load() async {
    if (_loaded) return;
    final pending = _loading ??= _load();
    try {
      await pending;
    } finally {
      if (identical(_loading, pending)) _loading = null;
    }
  }

  Future<void> _load() async {
    final saved = await _preferences.getString('mcp_connections');
    if (saved != null) {
      final parsed = (jsonDecode(saved) as List)
          .map((e) => McpConnection.fromJson(e as Map))
          .toList();
      _connections
        ..clear()
        ..addAll(parsed);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(McpConnection value) => _edit((items) {
    value.validate();
    if (items.any((c) => c.id != value.id && c.name == value.name))
      throw ArgumentError('连接名称已存在');
    final index = items.indexWhere((c) => c.id == value.id);
    if (index < 0) {
      if (items.length == 20) throw StateError('最多配置 20 个 MCP 连接');
      items.add(value);
    } else {
      items[index] = value;
    }
  });
  Future<void> remove(String id) =>
      _edit((items) => items.removeWhere((c) => c.id == id));
  Future<void> _edit(void Function(List<McpConnection>) edit) {
    final result = _pending.then((_) async {
      await load();
      final next = [..._connections];
      edit(next);
      await _preferences.setString(
        'mcp_connections',
        jsonEncode(next.map((c) => c.toJson()).toList()),
      );
      _connections
        ..clear()
        ..addAll(next);
      notifyListeners();
    });
    // The queue continues after an error; its caller still receives that error.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  McpConnection enabledNamed(String name) =>
      _connections.where((c) => c.name == name && c.enabled).firstOrNull ??
      (throw StateError('MCP connection is missing or disabled: $name'));
}
