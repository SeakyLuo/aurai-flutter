import 'provider_details.dart';

class RequestAdapter {
  const RequestAdapter({this.protocol, this.script = ''});
  final ProviderProtocol? protocol;
  final String script;
  Map<String, Object?> toJson() => {
    'protocol': protocol?.name,
    'script': script,
  };
  factory RequestAdapter.fromJson(Map<String, dynamic> json) => RequestAdapter(
    protocol: json['protocol'] == null
        ? null
        : ProviderProtocol.values.byName(json['protocol'] as String),
    script: json['script'] as String,
  );
}
