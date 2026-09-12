part of 'chat_controller.dart';

extension AccessibilityRequest on ChatController {
  Future<Map<String, Object?>> _requestAccessibility() async {
    await refreshCapabilities();
    final access = capabilities.firstWhere(
      (item) => item.id == 'android.accessibility',
    );
    if (access.isAvailable) {
      return const {
        'granted': true,
        'next': 'Call observeDevice before acting',
      };
    }
    if (access.availability != CapabilityAvailability.permissionRequired) {
      return {
        'granted': false,
        'reason': access.reason,
        'next':
            'Accessibility is already enabled but disconnected. Do not request permission again. Wait briefly and observeDevice again; if still disconnected, report the connection issue.',
      };
    }
    if (_accessibilityDeclined) {
      return const <String, Object?>{
        'granted': false,
        'reason': 'User already declined accessibility access for this task',
      };
    }
    if (_accessibilityRequest != null) {
      return _accessibilityRequest!.future;
    }
    final request = Completer<Map<String, Object?>>();
    _accessibilityRequest = request;
    _accessibilitySettingsOpened = false;
    _setAccessibilityDeadline(const Duration(seconds: 30));
    accessibilityRequestPending = true;
    _accessibilityChanged();
    return request.future;
  }

  void _setAccessibilityDeadline(Duration duration) {
    _accessibilityTimer?.cancel();
    accessibilityDeadline = DateTime.now().add(duration);
    _accessibilityTimer = Timer(
      duration,
      () => cancelAccessibilityRequest(timedOut: true),
    );
  }

  void _finishAccessibility(Map<String, Object?> result) {
    final request = _accessibilityRequest;
    if (request == null) return;
    _accessibilityTimer?.cancel();
    _accessibilityTimer = null;
    accessibilityDeadline = null;
    _accessibilityRequest = null;
    accessibilityRequestPending = false;
    request.complete(result);
    _accessibilityChanged();
  }

  Future<void> enableRequestedAccessibility() async {
    if (!accessibilityRequestPending) return;
    if (!_accessibilitySettingsOpened) {
      _accessibilitySettingsOpened = true;
      _setAccessibilityDeadline(const Duration(minutes: 2));
      _accessibilityChanged();
    }
    await openAccessibilitySettings();
  }

  Future<void> checkAccessibilityReturn() async {
    final request = _accessibilityRequest;
    if (request == null) return;
    await refreshCapabilities();
    if (!identical(request, _accessibilityRequest)) return;
    if (DateTime.now().isAfter(accessibilityDeadline!)) {
      cancelAccessibilityRequest(timedOut: true);
      return;
    }
    final granted = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    if (granted) {
      _finishAccessibility({
        'granted': true,
        'next': 'Call observeDevice again before acting',
      });
    }
  }

  void cancelAccessibilityRequest({bool timedOut = false}) {
    if (!accessibilityRequestPending) return;
    _accessibilityDeclined = true;
    _finishAccessibility({
      'granted': false,
      'reason': timedOut
          ? 'Accessibility permission request timed out and was automatically declined for this task'
          : 'User declined accessibility access for this task',
    });
  }
}
