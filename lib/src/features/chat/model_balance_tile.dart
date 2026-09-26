import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

import '../../domain/model_provider.dart';
import '../../providers/model_top_up.dart';
import '../../providers/model_balance.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelBalanceTile extends StatefulWidget {
  const ModelBalanceTile({
    super.key,
    required this.config,
    this.overview = false,
  });
  final ModelConfig config;
  final bool overview;

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
        oldWidget.config.service != widget.config.service ||
        oldWidget.config.balanceConfig != widget.config.balanceConfig) {
      _revision++;
      _client.close();
      _balance = null;
      _loading = false;
      _awaitingReturn = false;
      if (widget.config.isConfigured &&
          ModelBalanceClient.supports(widget.config)) {
        _query();
      }
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
      await ModelTopUp.open(widget.config);
    } on Object catch (error) {
      _awaitingReturn = false;
      if (mounted) _notice('无法打开服务商后台，请稍后再试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));

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
    final canTopUp = widget.config.rechargeUrl.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    final value = balance == null || !official
        ? Text(
            !official
                ? widget.config.rechargeUrl.isEmpty
                      ? '请在供应商网站查看余额'
                      : '${widget.config.displayName} 官方后台'
                : _loading
                ? '正在查询余额…'
                : widget.config.isConfigured
                ? '充值余额与${widget.config.balanceConfig!.grantedLabel}'
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
                    fontSize: widget.overview ? 24 : 34,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color:
                        widget.overview ||
                            Theme.of(context).brightness == Brightness.dark
                        ? colors.onSurface
                        : Colors.black,
                  ),
                ),
                if (!widget.overview) const SizedBox(height: 6),
                Text(
                  '充值余额 ${item.toppedUp} · ${widget.config.balanceConfig!.grantedLabel} ${item.granted}',
                ),
              ],
              if (!balance.available) const Text('当前账户无余额可供调用'),
              if (!widget.overview) const SizedBox(height: 4),
              Text(
                '查询于 ${time!.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              ),
            ],
          );
    final tile = ListTile(
      minVerticalPadding: widget.overview ? 0 : null,
      minTileHeight: widget.overview ? null : 64,
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.overview ? 8 : 18,
        vertical: widget.overview || !official || balance == null ? 0 : 14,
      ),
      shape: widget.overview
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            )
          : null,
      onTap: canTopUp && !_opening ? _topUp : null,
      titleTextStyle: widget.overview
          ? null
          : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: colors.onSurfaceVariant,
            ),
      title: widget.overview ? const Text('账户余额') : value,
      subtitle: widget.overview ? value : null,
      trailing: _loading || _opening
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : canTopUp
          ? const SettingsIcon(type: SettingsIconType.chevron)
          : null,
    );
    if (widget.overview) return tile;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: tile,
    );
  }
}
