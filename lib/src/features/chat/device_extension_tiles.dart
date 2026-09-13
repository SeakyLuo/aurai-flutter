import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/aurai_platform.dart';
import '../../utils/widget_utils.dart';
import 'capability_icon.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';

class DeviceExtensionTiles extends StatefulWidget {
  const DeviceExtensionTiles({super.key});

  @override
  State<DeviceExtensionTiles> createState() => _DeviceExtensionTilesState();
}

class _DeviceExtensionTilesState extends State<DeviceExtensionTiles>
    with WidgetsBindingObserver {
  final _platform = AuraiPlatform.instance;
  Map<String, Object?>? _state;
  Timer? _timer;
  final _busy = <String>{};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void _resume() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final state = await _platform.deviceExtension('getDeviceExtensions');
      if (mounted) setState(() => _state = state);
    } on PlatformException catch (error) {
      _timer?.cancel();
      _notice(error.message ?? '无法读取设备能力');
    } finally {
      _loading = false;
    }
  }

  Future<void> _perform(String id, Future<void> Function() action) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
    } on PlatformException catch (error) {
      _notice(error.message ?? '操作未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _shizuku(Map<Object?, Object?> state) =>
      _perform('android.execution.shizuku', () async {
        if (state['granted'] == true || state['running'] != true) {
          await _platform.openShizukuManager();
        } else {
          await _platform.deviceExtension('requestShizukuAccess');
        }
      });

  Future<void> _vpn(String status) async {
    if (status == 'running') {
      await _perform('android.network.capture', () async {
        await _platform.deviceExtension('stopNetworkCapture');
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .16),
      builder: (_) => const _StartVpnDialog(),
    );
    if (confirmed != true || !mounted) return;
    await _perform('android.network.capture', () async {
      await _platform.deviceExtension('startNetworkCapture', {
        'durationSeconds': 300,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final shizuku = state?['shizuku'] as Map<Object?, Object?>?;
    final vpn = state?['vpn'] as Map<Object?, Object?>?;
    final status = vpn?['status'] as String?;
    final running = status == 'running';
    final stopped = status == 'stopped';
    final remaining = vpn?['remainingSeconds'] as int?;
    return Column(
      children: [
        _row(
          'android.execution.shizuku',
          'Shizuku',
          shizuku?['reason'] as String? ?? '正在读取状态…',
          shizuku == null
              ? '加载中'
              : shizuku['granted'] == true
              ? '管理'
              : shizuku['running'] == true
              ? '授权'
              : shizuku['installed'] == true
              ? '去启动'
              : '去安装',
          shizuku == null ? null : () => _shizuku(shizuku),
          active: shizuku?['granted'] == true,
        ),
        _row(
          'android.network.capture',
          '本地 VPN',
          running
              ? '正在记录连接，剩余 ${((remaining! + 59) ~/ 60)} 分钟'
              : vpn?['reason'] as String? ?? '正在读取状态…',
          running
              ? '停止'
              : stopped
              ? '开启'
              : status == 'unsupported'
              ? '不支持'
              : status == 'stopping'
              ? '停止中'
              : status == null
              ? '加载中'
              : '开启中',
          running || stopped ? () => _vpn(status!) : null,
          active: running,
        ),
      ],
    );
  }

  Widget _row(
    String id,
    String title,
    String description,
    String label,
    VoidCallback? action, {
    required bool active,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = active
        ? (dark ? const Color(0xff6ee7b7) : const Color(0xff008577))
        : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy.contains(id) ? null : action,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 32,
                  child: Center(child: CapabilityIcon(id: id)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minWidth: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? (dark
                              ? const Color(0xff193b31)
                              : const Color(0xffe8f4f3))
                        : dark
                        ? const Color(0xff38383d)
                        : statusColor.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartVpnDialog extends StatelessWidget {
  const _StartVpnDialog();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassSurface(
          radius: 28,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '开启本地 VPN？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '记录其他应用的连接目标、时间和流量，5 分钟后自动停止，不读取 HTTPS 明文。\n\n这会替换当前 VPN，可能影响依赖它的联网。停止后，你需要自行重新连接原来的 VPN。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                WidgetUtils.primaryButton(
                  text: '开启',
                  height: 46,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    backgroundColor: dialogControlColor(context),
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
