part of 'html_view.dart';

extension _HtmlViewPresentation on _HtmlViewState {
  Iterable<_HtmlViewState> get _otherDisplays => _HtmlViewState._views.where(
    (view) =>
        !identical(view, this) &&
        view.widget.messageId == widget.messageId &&
        view.widget.surfaceId == widget.surfaceId &&
        view.widget.fullscreen != widget.fullscreen &&
        view._visible,
  );

  bool get _hasOtherDisplay => _otherDisplays.isNotEmpty;

  void _notifyPresentationVisibility() {
    if (_presentationVisible == _visible) return;
    _presentationVisible = _visible;
    for (final view in _HtmlViewState._views) {
      if (!identical(view, this)) view._scheduleVisibility();
    }
  }

  void _syncPresentation() {
    unawaited(
      _session?.updatePresentation(
        interactive: !_detailShowing,
        simultaneous: _hasOtherDisplay,
      ),
    );
  }

  void _focusDetails() {
    final detail = _otherDisplays.firstOrNull;
    if (detail != null) FocusScope.of(detail.context).requestFocus();
  }
}
