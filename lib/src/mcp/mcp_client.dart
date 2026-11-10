import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'mcp_settings.dart';

/// One bounded MCP session per operation. Failed connections are never retried.
class McpClient {
  McpClient(this.connection);
  final McpConnection connection;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  int _serial = 0;
  String? _session;
  bool _initialized = false;
  static const protocol = '2025-11-25';

  Future<void> initialize() async {
    if (_initialized) return;
    connection.validate();
    final result = await _request('initialize', {
      'protocolVersion': protocol,
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'aurai', 'version': '1.0.0'},
    }, initializing: true);
    if (result['protocolVersion'] != protocol)
      throw StateError(
        'Unsupported MCP protocol version: ${result['protocolVersion']}',
      );
    await _request('notifications/initialized', const {}, notification: true);
    _initialized = true;
  }

  Future<Map<String, dynamic>> listTools({String? cursor}) async {
    await initialize();
    return _request('tools/list', {if (cursor != null) 'cursor': cursor});
  }

  Future<Map<String, dynamic>> findTool(String name) async {
    String? cursor;
    for (var page = 0; page < 10; page++) {
      final result = await listTools(cursor: cursor);
      for (final tool in result['tools'] as List) {
        if (tool['name'] == name) return Map<String, dynamic>.from(tool as Map);
      }
      cursor = result['nextCursor'] as String?;
      if (cursor == null) throw StateError('MCP tool not found: $name');
    }
    throw StateError('MCP tool discovery exceeded 10 pages.');
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    await initialize();
    return _request('tools/call', {'name': name, 'arguments': arguments});
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, Object?> params, {
    bool initializing = false,
    bool notification = false,
  }) async {
    final id = ++_serial;
    final request = await _http.postUrl(Uri.parse(connection.url));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    if (connection.token.isNotEmpty)
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${connection.token}',
      );
    if (_session != null) request.headers.set('Mcp-Session-Id', _session!);
    if (!initializing) request.headers.set('MCP-Protocol-Version', protocol);
    request.write(
      jsonEncode({
        'jsonrpc': '2.0',
        if (!notification) 'id': id,
        'method': method,
        'params': params,
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (initializing) _session = response.headers.value('Mcp-Session-Id');
    if (notification && response.statusCode == HttpStatus.accepted) {
      await response.drain<void>();
      return {};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException(
        'HTTP ${response.statusCode} ${response.reasonPhrase}\n$body',
        uri: Uri.parse(connection.url),
      );
    }
    if (notification) {
      await response.drain<void>();
      return {};
    }
    Map<String, dynamic> decode(String text) {
      final rpc = jsonDecode(text) as Map<String, dynamic>;
      if (rpc['jsonrpc'] != '2.0' || rpc['id'] != id)
        throw FormatException('Unexpected MCP JSON-RPC response: $text');
      if (rpc.containsKey('error')) throw McpRemoteException(rpc['error']);
      return rpc['result'] as Map<String, dynamic>;
    }

    if (response.headers.contentType?.mimeType == 'text/event-stream') {
      final data = <String>[];
      await for (final line
          in utf8.decoder
              .bind(response)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 15))) {
        if (line.isEmpty && data.isNotEmpty) {
          final text = data.join('\n');
          data.clear();
          final rpc = jsonDecode(text) as Map;
          if (rpc['id'] == id) return decode(text);
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
        }
      }
      throw StateError('MCP SSE stream ended without a response.');
    }
    return decode(
      await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15)),
    );
  }

  void close() => _http.close(force: true);
}

class McpRemoteException implements Exception {
  McpRemoteException(this.error);
  final Object? error;
  @override
  String toString() => 'MCP JSON-RPC error: ${jsonEncode(error)}';
}
