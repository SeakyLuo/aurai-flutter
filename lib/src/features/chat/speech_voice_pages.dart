import 'package:flutter/foundation.dart';
import '../../domain/model_provider.dart';
import '../../providers/speech_voice_catalog.dart';

/// Fetches another page only when the list is scrolled.
class SpeechVoicePages extends ChangeNotifier {
  SpeechVoicePages(this.account)
    : voices = account.speechApi!.orderVoices(
        SpeechVoiceCatalog.cached(account) ?? const [],
      );
  final ModelConfig account;
  final _catalog = SpeechVoiceCatalog();
  List<SpeechVoice> voices;
  int total = 0;
  int _nextPage = 1;
  bool hasMore = true, loading = false;
  Future<void>? _pending;
  bool _disposed = false;
  final names = <String, String>{};

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadNext() => _pending ??= _loadNext();

  Future<void> _loadNext() async {
    loading = true;
    notifyListeners();
    try {
      final result = await _catalog.loadPage(account, _nextPage);
      if (_disposed) return;
      voices = _nextPage == 1
          ? result.voices
          : SpeechVoiceCatalog.merge(voices, result.voices);
      voices = voices.map((v) => v.renamed(names[v.id] ?? v.name)).toList();
      voices = account.speechApi!.orderVoices(voices);
      total = result.total;
      hasMore = result.hasMore;
      _nextPage++;
    } finally {
      loading = false;
      _pending = null;
      if (!_disposed) notifyListeners();
    }
  }
}
