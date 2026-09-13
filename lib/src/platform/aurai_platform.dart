import '../domain/ui_tool_actions.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/capability.dart';
import '../domain/model_provider.dart';

class AuraiPlatform {
  AuraiPlatform._();

  static final AuraiPlatform instance = AuraiPlatform._();
  static const MethodChannel _channel = MethodChannel(
    'com.haiskynology.aurai/platform',
  );

  Future<List<Capability>> loadCapabilities() async {
    if (!Platform.isAndroid) {
      return const <Capability>[
        Capability(
          id: 'android.network',
          name: 'Android 网络诊断',
          availability: CapabilityAvailability.unsupported,
          reason: '当前平台尚未实现网络适配器',
        ),
      ];
    }
    final items = await _channel.invokeListMethod<Object?>('getCapabilities');
    return items!
        .map((item) {
          final value = (item! as Map<Object?, Object?>)
              .cast<String, Object?>();
          return Capability(
            id: value['id']! as String,
            name: value['name']! as String,
            availability: CapabilityAvailability.values.byName(
              value['availability']! as String,
            ),
            reason: value['reason']! as String,
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, Object?>> inspectAndroidApi(
    Map<String, Object?> arguments,
  ) => _invokeMap('inspectAndroidApi', arguments);

  Future<Map<String, Object?>> executeAndroidScript(
    String callId,
    String script,
    String conversationId,
    int timeoutSeconds,
  ) => _invokeMap('executeAndroidScript', {
    'callId': callId,
    'script': script,
    'conversationId': conversationId,
    'timeoutSeconds': timeoutSeconds,
  });

  Future<void> cancelAndroidScript(String callId) =>
      _channel.invokeMethod<void>('cancelAndroidScript', {'callId': callId});

  Future<Map<String, Object?>> sendNotification(
    String title,
    String body,
    String conversationId,
  ) => _invokeMap('sendNotification', {
    'title': title,
    'body': body,
    'conversationId': conversationId,
  });

  Future<Map<String, Object?>> observeDevice() => _invokeMap('observeDevice');

  Future<Map<String, Object?>> getNotificationAccessState() =>
      _invokeMap('getNotificationAccessState');

  Future<Map<String, Object?>> getNotifications(
    int lookbackMinutes,
    int limit,
    String? appName,
  ) => _invokeMap('getNotifications', <String, Object?>{
    'lookbackMinutes': lookbackMinutes,
    'limit': limit,
    'appName': appName,
  });

  Future<Map<String, Object?>> act(
    String callId,
    Map<String, Object?> action,
  ) => _invokeMap('act', <String, Object?>{'callId': callId, ...action});

  Future<Map<String, Object?>> findApps(String query) =>
      _invokeMap('findApps', <String, Object?>{'query': query});

  Future<Map<String, Object?>> launchApp(String packageName) =>
      _invokeMap('launchApp', <String, Object?>{'packageName': packageName});

  Future<Map<String, Object?>> startIntent(Map<String, Object?> arguments) =>
      _invokeMap('startIntent', arguments);

  Future<void> openSourceFile(String uri) =>
      _channel.invokeMethod<void>('openSourceFile', {'uri': uri});

  Future<Map<String, Object?>> openSettings(String screen) =>
      _invokeMap('openSettings', <String, Object?>{'screen': screen});

  Future<void> openBatterySettings() =>
      _channel.invokeMethod<void>('openBatterySettings');

  Future<Map<String, Object?>> runAppShell(String command) =>
      _invokeMap('shell', <String, Object?>{'command': command});

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  Future<void> startAgentSession() =>
      _channel.invokeMethod<void>('startAgentSession');

  Future<void> updateAgentSessionStep(String step) =>
      _channel.invokeMethod<void>('updateAgentSessionStep', <String, Object?>{
        'step': step,
      });

  Future<void> endAgentSession(
    String outcome, {
    required String conversationId,
    required String title,
    required String reply,
  }) => _channel.invokeMethod<void>('endAgentSession', {
    'outcome': outcome,
    'conversationId': conversationId,
    'title': title,
    'reply': reply,
  });

  Future<String?> takeNotificationConversation() =>
      _channel.invokeMethod<String>('takeNotificationConversation');

  Future<Map<String, Object?>> getBackgroundRunReadiness() =>
      _invokeMap('getBackgroundRunReadiness');

  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  Future<bool> getScreenAccess() async =>
      (await _channel.invokeMethod<bool>('getScreenAccess'))!;

  Future<void> setScreenAccess(bool allowed) =>
      _channel.invokeMethod<void>('setScreenAccess', {'allowed': allowed});

  Future<bool> requestConfirmation(
    String callId,
    String toolName,
    Map<String, Object?> arguments,
    String? description,
    bool taskScoped,
    int confirmationTimeoutSeconds,
  ) async =>
      await _channel
          .invokeMethod<bool>('requestConfirmation', <String, Object?>{
            'callId': callId,
            'toolName': uiToolActions.containsKey(toolName) ? 'act' : toolName,
            'arguments': uiToolActions.containsKey(toolName)
                ? uiActionArguments(toolName, arguments)
                : arguments,
            'description': description,
            'taskScoped': taskScoped,
            'confirmationTimeoutSeconds': confirmationTimeoutSeconds,
          }) ??
      false;

  Future<void> cancelPendingInteraction() =>
      _channel.invokeMethod<void>('cancelPendingInteraction');

  Future<Map<String, Object?>> captureScreen() => _invokeMap('captureScreen');

  Future<Map<String, Object?>> preflightTapScreen(
    Map<String, Object?> arguments,
  ) => _invokeMap('preflightTapScreen', arguments);

  Future<Map<String, Object?>> tapScreen(
    String callId,
    Map<String, Object?> arguments,
  ) => _invokeMap('tapScreen', <String, Object?>{
    'callId': callId,
    ...arguments,
  });

  void setStopHandler(
    Future<void> Function() handler,
    void Function() onNotification,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopAgent') await handler();
      if (call.method == 'notificationOpened') onNotification();
    });
  }

  Future<Map<String, Object?>> getNetworkState() =>
      _invokeMap('getNetworkState');

  Future<Map<String, Object?>> getNetworkEvents() =>
      _invokeMap('getNetworkEvents');

  Future<Map<String, Object?>> dnsLookup(String host, int? networkHandle) =>
      _invokeMap('dnsLookup', <String, Object?>{
        'host': host,
        'networkHandle': networkHandle,
      });

  Future<Map<String, Object?>> tlsProbe(
    String host,
    int port,
    int attempts,
    int? networkHandle,
  ) => _invokeMap('tlsProbe', <String, Object?>{
    'host': host,
    'port': port,
    'attempts': attempts,
    'networkHandle': networkHandle,
  });

  Future<Map<String, Object?>> httpProbe(
    String url,
    String method,
    int attempts,
    int intervalMs,
    int? networkHandle,
    String route,
    String? proxyHost,
    int? proxyPort,
  ) => _invokeMap('httpProbe', <String, Object?>{
    'url': url,
    'method': method,
    'attempts': attempts,
    'intervalMs': intervalMs,
    'networkHandle': networkHandle,
    'route': route,
    'proxyHost': proxyHost,
    'proxyPort': proxyPort,
  });

  Future<void> cancelCurrentProbe() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('cancelCurrentProbe');
    }
  }

  Future<String?> loadLegacyAppState() async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('loadAppState');
  }

  Future<void> clearLegacyAppState() async {
    if (Platform.isAndroid)
      await _channel.invokeMethod<void>('clearLegacyAppState');
  }

  Future<ModelSettings> loadModelSettings() async {
    const environmentKey = String.fromEnvironment('AURAI_API_KEY');
    if (!Platform.isAndroid) {
      return ModelSettings.defaults(openAiApiKey: environmentKey);
    }
    final encoded = await _channel.invokeMethod<String>('loadModelConfig');
    if (encoded == null) {
      return ModelSettings.defaults(openAiApiKey: environmentKey);
    }
    return ModelSettings.fromJson(
      (jsonDecode(encoded) as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  Future<void> saveModelSettings(ModelSettings settings) async {
    if (!Platform.isAndroid) {
      throw PlatformException(code: 'unsupported', message: '当前平台尚未实现安全配置存储');
    }
    await _channel.invokeMethod<void>('saveModelConfig', <String, Object?>{
      'config': jsonEncode(settings.toJson()),
    });
  }

  Future<Map<String, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!Platform.isAndroid) {
      throw PlatformException(
        code: 'unsupported',
        message: '$method 尚未在当前平台实现',
      );
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      method,
      arguments,
    );
    return result!;
  }
}
