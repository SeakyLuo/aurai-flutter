part of 'html_view.dart';

extension _HtmlViewPreviews on _HtmlViewState {
  Future<void> _openProfile(String senderId) async {
    if (_profileOpen) return;
    _profileOpen = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    // Acknowledge the HTML click immediately; navigation completes on return.
    unawaited(_showProfile(senderId));
  }

  Future<void> _showProfile(String senderId) async {
    try {
      await widget.onOpenProfile!(senderId);
    } finally {
      _profileOpen = false;
      if (mounted) _scheduleVisibility();
    }
  }

}
