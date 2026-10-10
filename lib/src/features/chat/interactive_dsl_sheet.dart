import 'package:flutter/material.dart';
import 'app_sheet_body.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';
import 'glass_surface.dart';

/// A local presentation route. Form data and message actions stay with the card.
class InteractiveDslSheetController {
  ModalBottomSheetRoute<void>? _route;
  NavigatorState? _navigator;
  ValueNotifier<int>? _changes;
  bool _disposed = false;

  void refresh() {
    if (_changes case final changes?) changes.value++;
  }

  void close() {
    final route = _route;
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      _navigator!.pop();
    } else {
      _navigator!.removeRoute(route);
    }
  }

  void dispose() {
    _disposed = true;
    // The owning message can disappear during a build or navigation transition.
    WidgetsBinding.instance.addPostFrameCallback((_) => close());
  }

  Future<void> show(
    BuildContext context, {
    required String title,
    required Widget Function() buildContent,
    bool resizeToAvoidBottomInset = false,
  }) async {
    if (_route != null) return;
    final navigator = Navigator.of(context);
    final changes = ValueNotifier(0);
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: changes,
        builder: (context, _, _) => _disposed
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(
                  bottom: resizeToAvoidBottomInset
                      ? MediaQuery.viewInsetsOf(context).bottom
                      : 0,
                ),
                child: SafeArea(
                  top: false,
                  maintainBottomViewPadding: !resizeToAvoidBottomInset,
                  child: FractionallySizedBox(
                    heightFactor: .85,
                    child: AppSheetBody(
                      header: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            SettingsGlassAction(
                              icon: Icons.close_rounded,
                              iconWidget: const QuestionIcon(
                                type: QuestionIconType.close,
                              ),
                              label: '关闭',
                              onPressed: close,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12 + RoundAction.defaultSize),
                          ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
                        child: buildContent(),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
    _route = route;
    _navigator = navigator;
    _changes = changes;
    await navigator.push(route);
    await route.completed;
    _route = null;
    _navigator = null;
    _changes = null;
    changes.dispose();
  }
}
