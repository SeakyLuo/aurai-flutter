import 'dart:async';

import 'package:flutter/material.dart';

import '../app/ui_action.dart';
import '../domain/message_sender.dart';
import '../features/chat/floating_search_layout.dart';
import '../features/chat/group_member_choice.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/pagination_listener.dart';
import '../features/chat/settings_appearance.dart';
import '../widgets/empty_data_view.dart';
import 'miniapp_team_store.dart';

class MiniappTeamPicker extends StatefulWidget {
  const MiniappTeamPicker({
    super.key,
    required this.store,
    required this.appId,
  });
  final MiniappTeamStore store;
  final String appId;
  @override
  State<MiniappTeamPicker> createState() => _MiniappTeamPickerState();
}

class _MiniappTeamPickerState extends State<MiniappTeamPicker> {
  final _search = TextEditingController();
  final _members = <MessageSender>[];
  final _selected = <String, MessageSender>{};
  bool _loading = false, _more = true, _failed = false;
  int _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) _members.clear();
    });
    final ok = await runUiAction(context, () async {
      final members = await widget.store.candidates(
        widget.appId,
        offset: _members.length,
        query: _search.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _members.addAll(members);
        _more = members.length == MiniappTeamStore.pageSize;
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
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '添加开发成员',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '完成',
          icon: Icons.check_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.check),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.values.toList()),
        ),
      ],
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: FloatingSearchLayout(
          controller: _search,
          hintText: '搜索成员',
          itemCount: _members.length,
          onChanged: (_) {
            _debounce?.cancel();
            ++_generation;
            _debounce = Timer(
              const Duration(milliseconds: 250),
              () => _load(reset: true),
            );
          },
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
                    const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      FloatingSearchLayout.clearance,
                    ),
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverList.list(
                        children: [
                          for (final member in _members)
                            GroupMemberChoice(
                              sender: member,
                              selected: _selected.containsKey(member.id),
                              onTap: () => setState(() {
                                if (_selected.containsKey(member.id)) {
                                  _selected.remove(member.id);
                                } else {
                                  _selected[member.id] = member;
                                }
                              }),
                            ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                      if (!_loading && !_failed && _members.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyDataView(title: '没有可添加的成员'),
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
  );
}
