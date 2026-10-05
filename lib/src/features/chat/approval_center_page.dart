import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../storage/approval_center_store.dart';
import '../../widgets/empty_data_view.dart';
import 'approval_request_dialog.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'search_type_segment.dart';

class ApprovalCenterPage extends StatefulWidget {
  const ApprovalCenterPage({super.key, required this.store});
  final ApprovalCenterStore store;
  @override
  State<ApprovalCenterPage> createState() => _ApprovalCenterPageState();
}

class _ApprovalCenterPageState extends State<ApprovalCenterPage> {
  final _rows = <Map<String, Object?>>[];
  bool _pending = true, _loading = false, _more = true, _failed = false;
  int _generation = 0;
  late final StreamSubscription<void> _changes;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _changes = ApprovalCenterStore.changes.stream.listen(
      (_) => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await runUiAction(context, () async {
      final rows = await widget.store.page(
        pending: _pending,
        offset: reset ? 0 : _rows.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll(rows);
        _more = rows.length == 50;
      });
    });
    if (mounted && generation == _generation)
      setState(() {
        _loading = false;
        _failed = !ok;
      });
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '',
      titleWidget: SearchTypeSegment(
        files: !_pending,
        labels: const ['待审批', '已审批'],
        onChanged: (value) {
          setState(() {
            _pending = !value;
            _rows.clear();
          });
          _load(reset: true);
        },
      ),
      onBack: () => Navigator.pop(context),
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                SizedBox(height: settingsHeaderHeight(context)),
                Expanded(
                  child: PaginationListener(
                    hasMore: _more && !_loading && !_failed,
                    failed: _failed,
                    onRetry: () => _load(reset: true),
                    loadMore: _load,
                    child: !_loading && !_failed && _rows.isEmpty
                        ? EmptyDataView(title: _pending ? '暂无待审批申请' : '暂无已审批记录')
                        : CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  24,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    for (final row in _rows)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Material(
                                          color: settingsFieldColor(context),
                                          borderRadius: BorderRadius.circular(
                                            26,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 18,
                                                  vertical: 10,
                                                ),
                                            leading: const SettingsIcon(
                                              type: SettingsIconType.permission,
                                            ),
                                            title: Text(
                                              '${row['title']}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              '${row['sender_name']} · ${approvalTime(row['requested_at'] as int)}\n${approvalStatus(row['status'] as String)}',
                                            ),
                                            trailing: const SettingsIcon(
                                              type: SettingsIconType.chevron,
                                            ),
                                            onTap: () => runUiAction(
                                              context,
                                              () async {
                                                final current = await widget
                                                    .store
                                                    .read(row['id'] as String);
                                                if (context.mounted)
                                                  await showApprovalRequest(
                                                    context,
                                                    widget.store,
                                                    current,
                                                  );
                                              },
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
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
