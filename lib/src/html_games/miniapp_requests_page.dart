import 'dart:async';

import 'package:flutter/material.dart';

import '../app/ui_action.dart';
import '../domain/message_sender.dart';
import '../features/chat/dialog_action_button.dart';
import '../features/chat/pagination_listener.dart';
import '../features/chat/settings_appearance.dart';
import '../widgets/empty_data_view.dart';
import 'miniapp_team_page.dart';
import 'miniapp_team_store.dart';

class MiniappRequestsPage extends StatefulWidget {
  const MiniappRequestsPage({super.key, required this.store, this.appId});
  final MiniappTeamStore store;
  final String? appId;
  @override
  State<MiniappRequestsPage> createState() => _MiniappRequestsPageState();
}

class _MiniappRequestsPageState extends State<MiniappRequestsPage> {
  final _rows = <Map<String, Object?>>[];
  bool _loading = false, _more = true, _failed = false, _busy = false;
  int _generation = 0;
  late final StreamSubscription<String> _changes;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _changes = MiniappTeamStore.changes.stream.listen((id) {
      if (widget.appId == null || id == widget.appId) _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await runUiAction(context, () async {
      final rows = await widget.store.pending(
        MessageSender.localUser.id,
        offset: reset ? 0 : _rows.length,
        appId: widget.appId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll(rows);
        _more = rows.length == MiniappTeamStore.pageSize;
      });
    });
    if (mounted && generation == _generation)
      setState(() {
        _loading = false;
        _failed = !ok;
      });
  }

  Future<void> _review(Map<String, Object?> row, bool approve) async {
    setState(() => _busy = true);
    await runUiAction(
      context,
      () => widget.store.manage(
        row['appId'] as String,
        MessageSender.localUser.id,
        approve ? 'approve' : 'reject',
        row['senderId'] as String,
        requestedAt: row['requestedAt'] as int,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(title: '修改申请', onBack: () => Navigator.pop(context)),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: PaginationListener(
              hasMore: _more && !_loading && !_failed,
              failed: _failed,
              onRetry: () => _load(reset: true),
              loadMore: _load,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: settingsPagePadding(
                      context,
                      const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverList.list(
                          children: [
                            for (final row in _rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: settingsFieldColor(context),
                                  borderRadius: BorderRadius.circular(22),
                                  clipBehavior: Clip.antiAlias,
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${row['name']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        if (widget.appId == null)
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              alignment: Alignment.centerLeft,
                                              padding: EdgeInsets.zero,
                                            ),
                                            onPressed: () =>
                                                Navigator.push<void>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        MiniappTeamPage(
                                                          store: widget.store,
                                                          appId:
                                                              row['appId']
                                                                  as String,
                                                        ),
                                                  ),
                                                ),
                                            child: Text('${row['title']}'),
                                          ),
                                        const SizedBox(height: 8),
                                        Text('${row['reason']}'),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DialogActionButton(
                                                text: '拒绝',
                                                role:
                                                    DialogActionRole.secondary,
                                                onPressed: _busy || _loading
                                                    ? null
                                                    : () => _review(row, false),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: DialogActionButton(
                                                text: '批准加入',
                                                onPressed: _busy || _loading
                                                    ? null
                                                    : () => _review(row, true),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                        if (!_loading && !_failed && _rows.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyDataView(title: '暂无修改申请'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
