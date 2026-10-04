import 'provider_details.dart';

class RequestAdapter {
  const RequestAdapter({ProviderProtocol? protocol, String script = ''})
    : _protocol = protocol,
      _script = script,
      _json = null;

  // Load saved adapters without interpreting executable configuration during
  // app startup. Resolve it only when this adapter is actually used, and keep
  // the original data intact when unrelated settings are saved.
  RequestAdapter.fromJson(Map<String, dynamic> json)
    : _json = Map.unmodifiable(json),
      _protocol = null,
      _script = null;

  final Map<String, dynamic>? _json;
  final ProviderProtocol? _protocol;
  final String? _script;

  ProviderProtocol? get protocol {
    final json = _json;
    if (json == null) return _protocol;
    return json['protocol'] == null
        ? null
        : ProviderProtocol.values.byName(json['protocol'] as String);
  }

  String get script => _json == null ? _script! : _json['script'] as String;

  Map<String, Object?> toJson() => _json == null
      ? {'protocol': protocol?.name, 'script': script}
      : Map<String, Object?>.of(_json);
}
