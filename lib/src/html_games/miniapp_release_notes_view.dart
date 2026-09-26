import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'miniapp_release_notes.dart';

class MiniappReleaseNotesView extends StatefulWidget {
  const MiniappReleaseNotesView({
    super.key,
    required this.database,
    required this.appId,
  });
  final Database database;
  final String appId;
  @override
  State<MiniappReleaseNotesView> createState() =>
      _MiniappReleaseNotesViewState();
}

class _MiniappReleaseNotesViewState extends State<MiniappReleaseNotesView> {
  final _notes = <MiniappReleaseNote>[];
  bool _loading = true, _more = false, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final notes = await readMiniappReleaseNotes(
        widget.database,
        widget.appId,
        beforeRevision: _notes.lastOrNull?.revision,
        limit: 21,
      );
      if (!mounted) return;
      setState(() {
        _notes.addAll(notes.take(20));
        _more = notes.length > 20;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty && !_failed) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          '更新日志',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final note in _notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${note.revision} 版 · ${note.createdAt.year}.${note.createdAt.month.toString().padLeft(2, '0')}.${note.createdAt.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note.notes,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (!_loading && (_more || _failed))
          TextButton(onPressed: _load, child: Text(_failed ? '重试' : '更早版本')),
      ],
    );
  }
}
