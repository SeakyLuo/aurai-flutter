import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

import '../../domain/model_provider.dart';
import '../../providers/model_top_up.dart';
import '../../providers/model_balance.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelBalanceTile extends StatefulWidget {
  const ModelBalanceTile({super.key, required this.config});
  final ModelConfig config;

  @override
  State<ModelBalanceTile> createState() => _ModelBalanceTileState();
}

class _ModelBalanceTileState extends State<ModelBalanceTile>
    with WidgetsBindingObserver {
  final _client = ModelBalanceClient();
  ModelBalance? _balance;
  bool _loading = false;
  bool _opening = false;
  bool _awaitingReturn = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.config.isConfigured &&
        ModelBalanceClient.supports(widget.config)) {
      _query();
    }
  }

  @override
  void didUpdateWidget(ModelBalanceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.apiKey != widget.config.apiKey ||
        oldWidget.config.baseUrl != widget.config.baseUrl ||
        oldWidget.config.service != widget.config.service) {
      _revision++;
      _client.close();
      _balance = null;
      _loading = false;
      _awaitingReturn = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      if (!_loading &&
          widget.config.isConfigured &&
          ModelBalanceClient.supports(widget.config))
        _query();
    }
  }

  Future<void> _query() async {
    final revision = _revision;
    setState(() => _loading = true);
    try {
      final balance = await _client.load(widget.config);
      if (mounted && revision == _revision) setState(() => _balance = balance);
    } on ModelProviderException catch (error) {
      if (mounted && revision == _revision) _notice(error.message);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _topUp() async {
    FocusScope.of(context).unfocus();
    setState(() => _opening = true);
    _awaitingReturn = true;
    try {
      if (ModelBalanceClient.supports(widget.config) &&
          widget.config.service == ModelService.deepSeek) {
        await ModelTopUp.open(widget.config);
      } else {
        await ModelTopUp.openConsole(widget.config.service);
      }
    } on Object catch (error) {
      _awaitingReturn = false;
      if (mounted) _notice('无法打开服务商后台，请稍后再试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balance;
    final time = balance?.checkedAt.toLocal();
    final official = ModelBalanceClient.supports(widget.config);
    final canTopUp =
        !official || widget.config.service == ModelService.deepSeek;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 64,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: official && balance != null ? 14 : 0,
        ),
        onTap: canTopUp && !_opening ? _topUp : null,
        titleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          color: colors.onSurfaceVariant,
        ),
        title: balance == null || !official
            ? Text(
                !official
                    ? '${widget.config.service.label} 官方后台'
                    : _loading
                    ? '正在查询余额…'
                    : widget.config.isConfigured
                    ? '充值余额与赠金'
                    : '配置密钥后可查看账户余额',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, item) in balance.balances.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Text(
                      '${item.currency == 'CNY'
                          ? '￥'
                          : item.currency == 'USD'
                          ? '\$'
                          : '${item.currency} '}${double.parse(item.total).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? colors.onSurface
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '充值余额 ${item.toppedUp} · ${widget.config.service == ModelService.kimi ? '代金券' : '赠金'} ${item.granted}',
                    ),
                  ],
                  if (!balance.available) const Text('当前账户无余额可供调用'),
                  const SizedBox(height: 4),
                  Text(
                    '查询于 ${time!.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
        trailing: _loading || _opening
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : canTopUp
            ? const SettingsIcon(type: SettingsIconType.chevron)
            : null,
      ),
    );
  }
}
