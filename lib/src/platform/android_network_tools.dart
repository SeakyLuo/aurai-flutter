import '../domain/error_message.dart';
import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'aurai_platform.dart';

class GetNetworkEventsTool implements AgentTool {
  GetNetworkEventsTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'getNetworkEvents',
    description:
        'Read the bounded Android network transition history captured since Aurai started, including available/lost/capability/link changes. Use it for intermittent failures.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.network',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: await _platform.getNetworkEvents(),
      );
    } on PlatformException catch (error) {
      return _platformError(call, error);
    }
  }

  @override
  Future<void> cancel() async {}
}

class GetNetworkStateTool implements AgentTool {
  GetNetworkStateTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'getNetworkState',
    description:
        'Read active Android network, Wi-Fi/cellular/VPN transports, DNS, routes, proxy, validation and metering state.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.network',
  );

  @override
  Future<ToolResult> execute(ToolCall call) => _execute(call);

  Future<ToolResult> _execute(ToolCall call) async {
    try {
      final output = await _platform.getNetworkState();
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on PlatformException catch (error) {
      return _platformError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelCurrentProbe();
}

class DnsLookupTool implements AgentTool {
  DnsLookupTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'dnsLookup',
    description:
        'Resolve a hostname with the Android system resolver on the current network.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'host': <String, Object?>{
          'type': 'string',
          'description': 'Hostname to resolve, without a URL scheme.',
        },
        'networkHandle': <String, Object?>{
          'type': <String>['integer', 'null'],
          'description':
              'Optional networkHandle from getNetworkState. Use null for Android default routing.',
        },
      },
      'required': <String>['host', 'networkHandle'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.network',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.dnsLookup(
        call.arguments['host']! as String,
        call.arguments['networkHandle'] as int?,
      );
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on PlatformException catch (error) {
      return _platformError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelCurrentProbe();
}

class TlsProbeTool implements AgentTool {
  TlsProbeTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'tlsProbe',
    description:
        'Resolve through the selected Android network, then open a TCP/TLS connection and inspect protocol, cipher, certificate chain, issuer, SAN, validity, hostname match and Android trust. Failed attempts retain their completed DNS/TCP evidence and bounded cause chain.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'host': <String, Object?>{
          'type': 'string',
          'description': 'TLS server hostname, without a URL scheme.',
        },
        'port': <String, Object?>{
          'type': 'integer',
          'description': 'TCP port, normally 443 for HTTPS.',
        },
        'attempts': <String, Object?>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 10,
          'description':
              'Number of consecutive probes. Use multiple attempts for intermittent failures.',
        },
        'networkHandle': <String, Object?>{
          'type': <String>['integer', 'null'],
          'description':
              'Optional networkHandle from getNetworkState. Use null for Android default routing.',
        },
      },
      'required': <String>['host', 'port', 'attempts', 'networkHandle'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.network',
    executionTimeout: Duration(seconds: 110),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.tlsProbe(
        call.arguments['host']! as String,
        call.arguments['port']! as int,
        call.arguments['attempts']! as int,
        call.arguments['networkHandle'] as int?,
      );
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on PlatformException catch (error) {
      return _platformError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelCurrentProbe();
}

class HttpProbeTool implements AgentTool {
  HttpProbeTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'httpProbe',
    description:
        'Make repeated HTTPS GET or HEAD requests and classify failures by DNS, TCP connect, TLS certificate validation, TLS handshake, timeout, or HTTP response. Failed attempts retain completed DNS/TCP observations, endpoints, stage timing, and bounded cause chains so intermittent path failures can be correlated.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'url': <String, Object?>{
          'type': 'string',
          'description': 'Complete HTTPS URL, including the path to probe.',
        },
        'method': <String, Object?>{
          'type': 'string',
          'enum': <String>['GET', 'HEAD'],
        },
        'attempts': <String, Object?>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 60,
          'description':
              'Number of independent HTTPS connections to make. A longer bounded run can capture intermittent failures and remains user-stoppable.',
        },
        'intervalMs': <String, Object?>{
          'type': 'integer',
          'minimum': 0,
          'maximum': 30000,
          'description': 'Delay between attempts in milliseconds.',
        },
        'networkHandle': <String, Object?>{
          'type': <String>['integer', 'null'],
          'description':
              'Optional networkHandle from getNetworkState. Use null for Android default routing.',
        },
        'route': <String, Object?>{
          'type': 'string',
          'enum': <String>['android', 'socks5'],
          'description':
              'android uses Android routing; socks5 connects through a local or reachable SOCKS5 proxy.',
        },
        'proxyHost': <String, Object?>{
          'type': <String>['string', 'null'],
          'description': 'SOCKS5 proxy host, or null for the android route.',
        },
        'proxyPort': <String, Object?>{
          'type': <String>['integer', 'null'],
          'description': 'SOCKS5 proxy port, or null for the android route.',
        },
      },
      'required': <String>[
        'url',
        'method',
        'attempts',
        'intervalMs',
        'networkHandle',
        'route',
        'proxyHost',
        'proxyPort',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.network',
    executionTimeout: Duration(seconds: 2500),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.httpProbe(
        call.arguments['url']! as String,
        call.arguments['method']! as String,
        call.arguments['attempts']! as int,
        call.arguments['intervalMs']! as int,
        call.arguments['networkHandle'] as int?,
        call.arguments['route']! as String,
        call.arguments['proxyHost'] as String?,
        call.arguments['proxyPort'] as int?,
      );
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on PlatformException catch (error) {
      return _platformError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelCurrentProbe();
}

ToolResult _platformError(ToolCall call, PlatformException error) => ToolResult(
  callId: call.id,
  toolName: call.name,
  status: error.code == 'cancelled'
      ? ToolResultStatus.cancelled
      : ToolResultStatus.error,
  output: <String, Object?>{'error': errorMessage(error), 'code': error.code},
);

ToolResult platformToolError(ToolCall call, PlatformException error) =>
    _platformError(call, error);
