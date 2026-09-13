import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class DeviceExtensionTool implements AgentTool, RuntimeCapabilityAgentTool {
  DeviceExtensionTool(this.platform, this.name);
  final AuraiPlatform platform;
  final String name;

  static const names = [
    'getDeviceExtensions',
    'requestShizukuAccess',
    'executeShizuku',
    'startNetworkCapture',
    'stopNetworkCapture',
    'readNetworkTraffic',
    'clearNetworkTraffic',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    waitsForUser:
        name == 'requestShizukuAccess' || name == 'startNetworkCapture',
    capabilityId: name.contains('Shizuku')
        ? 'android.execution.shizuku'
        : 'android.network.capture',
    description: switch (name) {
      'getDeviceExtensions' =>
        '查看 Shizuku 安装、运行、授权和实际执行身份，以及本地 VPN 的状态、剩余时长、是否有其他 VPN。先检查再操作，不把 Shizuku 当作必然拥有 root。',
      'requestShizukuAccess' =>
        '用户需要更高权限设备操作时，引导安装/启动 Shizuku 或请求授权。必须在 Aurai 前台，已授权不重复请求；用户拒绝后不要循环重试。打开管理器不代表授权成功，返回后查询状态。',
      'executeShizuku' =>
        '通过已授权的 Shizuku UserService 执行 shell 命令，返回实际 UID、退出码和有界输出。与普通 shell 工具分开，不能暗中升级权限。ADB 身份仍不能读取其他应用私有数据。命令应以前台方式运行，不启动脱离任务的后台进程；超时或取消会终止执行。',
      'startNetworkCapture' =>
        '经用户明确同意，启动手机本地 VPN 记录其他应用的 TCP/UDP 连接元数据并正常转发。将替换现有 VPN（可能使依赖它的网络不可达），不解密 HTTPS，不安装证书，不提供请求 URL/正文；Aurai 自身除外。必须在 Aurai 前台接受系统授权，30–1800 秒后自动停止。不要用于普通发送通知，也不要无任务理由自动启动。',
      'stopNetworkCapture' =>
        '停止 Aurai 本地 VPN 并释放转发连接，恢复系统普通网络路由。不会自动重新连接先前的 VPN。记录保留到清除或进程结束。',
      'readNetworkTraffic' =>
        '读取本次本地 VPN 的连接元数据：目标 IP/主机、端口、协议、时间、字节数和连接状态。仅内存保留最近 500 条；after=0 从当前保留记录开始，按 nextCursor 继续（单次最多 100 条）。游标只取新增连接，查看既有连接的更新请从 after=0 读取。没有 HTTPS 明文、请求链接、Cookie 或请求体，不要推断看不到的内容。',
      'clearNetworkTraffic' => '清除内存网络连接记录，不会停止正在运行的 VPN。',
      _ => throw StateError('Unknown device extension tool'),
    },
    inputSchema: {
      'type': 'object',
      'properties': switch (name) {
        'executeShizuku' => {
          'command': {'type': 'string', 'minLength': 1, 'maxLength': 32768},
          'timeoutSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 120},
        },
        'startNetworkCapture' => {
          'durationSeconds': {
            'type': 'integer',
            'minimum': 30,
            'maximum': 1800,
          },
        },
        'readNetworkTraffic' => {
          'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
          'after': {'type': 'integer', 'minimum': 0},
        },
        _ => <String, Object?>{},
      },
      'required': switch (name) {
        'executeShizuku' => ['command', 'timeoutSeconds'],
        'startNetworkCapture' => ['durationSeconds'],
        'readNetworkTraffic' => ['limit', 'after'],
        _ => <String>[],
      },
      'additionalProperties': false,
    },
    safety: switch (name) {
      'executeShizuku' => ToolSafety.destructive,
      'startNetworkCapture' => ToolSafety.sensitive,
      'requestShizukuAccess' ||
      'stopNetworkCapture' ||
      'clearNetworkTraffic' => ToolSafety.lowRisk,
      _ => ToolSafety.readOnly,
    },
    executionTimeout: const Duration(seconds: 150),
    confirmationDescriptionBuilder: name == 'startNetworkCapture'
        ? (args) =>
              '开启本地 VPN，记录其他应用的连接元数据，${args['durationSeconds']} 秒后自动停止。这会替换当前 VPN，可能影响依赖它的联网；不读取 HTTPS 明文。停止后需自行重新连接原 VPN。'
        : name == 'executeShizuku'
        ? (args) => '通过 Shizuku 的已授权身份执行命令：\n${args['command']}'
        : null,
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await platform.deviceExtension(name, call.arguments);
      return ToolResult(
        callId: call.id,
        toolName: name,
        status:
            output['timedOut'] == true ||
                (name == 'executeShizuku' && output['exitCode'] != 0)
            ? ToolResultStatus.error
            : ToolResultStatus.success,
        output: output,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<void> cancel() async {
    if (name == 'executeShizuku') await platform.cancelShizuku();
    if (name == 'startNetworkCapture')
      await platform.cancelNetworkCaptureStart();
  }
}
