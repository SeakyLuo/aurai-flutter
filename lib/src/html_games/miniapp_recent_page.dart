import 'package:flutter/material.dart';
import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/settings_appearance.dart';
import 'html_store.dart';
import 'miniapp_icon.dart';
import 'miniapp_launcher.dart';
import 'miniapp_library_store.dart';

class MiniappRecentPage extends StatefulWidget {
  const MiniappRecentPage({super.key, required this.store});
  final HtmlStore store;
  @override
  State<MiniappRecentPage> createState() => _MiniappRecentPageState();
}

class _MiniappRecentPageState extends State<MiniappRecentPage> {
  late final _library = MiniappLibraryStore(widget.store.database);
  final _entries = <MiniappEntry>[];
  bool _loading = false, _more = true, _opening = false;
  int? _time;
  String? _id;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await _library.recent(
        beforeTime: reset ? null : _time,
        beforeId: reset ? null : _id,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _entries.clear();
        _entries.addAll(result.entries);
        _more = result.more;
        _time = result.time;
        _id = result.id;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MiniappEntry entry) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openMiniapp(context, entry, widget.store);
      if (mounted) await _load(reset: true);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '最近使用',
      gradientBackground: true,
      onBack: () => Navigator.pop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _loading && _entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + 76 + 16,
                    16,
                    16,
                  ),
                  children: [
                    if (_entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('还没有使用过小程序')),
                      ),
                    for (final entry in _entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: settingsFieldColor(context),
                          borderRadius: BorderRadius.circular(22),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            leading: MiniappIcon(
                              path: entry.iconPath,
                              asset: entry.iconAsset,
                              size: 48,
                            ),
                            title: Text(
                              entry.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: _opening ? null : () => _open(entry),
                          ),
                        ),
                      ),
                    if (_more && _entries.isNotEmpty)
                      TextButton(
                        onPressed: _loading ? null : _load,
                        child: Text(_loading ? '正在加载' : '加载更多'),
                      ),
                  ],
                ),
        ),
      ),
    ),
  );
}
