import 'package:flutter/material.dart';
import 'message_action.dart';
import 'glass_surface.dart';
import '../../app/global_ui.dart';
import 'chat_viewport.dart';
import 'chat_header.dart';
import 'group_message_heading.dart';

Future<MessageMenuResult?> showMessageMenuSheet(
  BuildContext context, {
  required bool preserveSelection,
  required Widget Function(BuildContext, ValueChanged<MessageMenuResult>)
  builder,
}) async {
  const color = Colors.transparent;
  final shape = Theme.of(context).bottomSheetTheme.shape;
  if (!preserveSelection) {
    // The menu supplies its glass surface; do not add an opaque sheet beneath it.
    return showModalBottomSheet<MessageMenuResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      elevation: 0,
      backgroundColor: color,
      barrierColor: Colors.transparent,
      shape: shape,
      // GlassSurface owns clipping; a parent saveLayer hides the backdrop.
      clipBehavior: Clip.none,
      builder: (sheetContext) => _MessageMenuSurface(
        messageContext: context,
        child: builder(
          sheetContext,
          (result) => Navigator.pop(sheetContext, result),
        ),
      ),
    );
  }
  final route = _SelectionMessageMenuRoute(
    builder: (sheetContext) => _MessageMenuSurface(
      messageContext: context,
      child: builder(
        sheetContext,
        (result) => Navigator.pop(sheetContext, result),
      ),
    ),
    backgroundColor: color,
    shape: shape,
  );
  final result = await Navigator.of(context).push(route);
  await route.completed;
  return result;
}

class _SelectionMessageMenuRoute
    extends ModalBottomSheetRoute<MessageMenuResult> {
  _SelectionMessageMenuRoute({
    required super.builder,
    required super.backgroundColor,
    required super.shape,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         showDragHandle: false,
         elevation: 0,
         requestFocus: false,
         isDismissible: true,
         clipBehavior: Clip.none,
       );

  // Dismiss the full menu before adjusting the retained text selection.
  @override
  Widget buildModalBarrier() => ModalBarrier(
    dismissible: true,
    onDismiss: () => navigator!.pop(const MessageMenuDismissResult()),
    semanticsLabel: barrierLabel,
  );
}

class _MessageMenuSurface extends StatefulWidget {
  const _MessageMenuSurface({
    required this.messageContext,
    required this.child,
  });
  final BuildContext messageContext;
  final Widget child;

  @override
  State<_MessageMenuSurface> createState() => _MessageMenuSurfaceState();
}

class _MessageMenuSurfaceState extends State<_MessageMenuSurface> {
  ChatViewportState? _viewport;

  @override
  void initState() {
    super.initState();
    _viewport = widget.messageContext
        .findAncestorStateOfType<ChatViewportState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealMessage());
  }

  Future<void> _revealMessage() async {
    if (!mounted || !widget.messageContext.mounted) return;
    final height = (context.findRenderObject()! as RenderBox).size.height;
    _viewport?.reserveMessageMenuSpace(height);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !widget.messageContext.mounted) return;
    var box = widget.messageContext.findRenderObject()! as RenderBox;
    widget.messageContext.visitAncestorElements((element) {
      if (element.widget is GroupMessageHeading) {
        box = element.findRenderObject()! as RenderBox;
        return false;
      }
      return true;
    });
    final top = box.localToGlobal(Offset.zero).dy;
    final visibleBottom = MediaQuery.sizeOf(context).height - height - 12;
    final viewport = _viewport;
    final safeTop = viewport == null
        ? MediaQuery.paddingOf(widget.messageContext).top +
              ChatHeader.toolbarHeight +
              12
        : (viewport.context.findRenderObject()! as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy +
              viewport.widget.padding.top;
    final lowestTop = (visibleBottom - box.size.height).clamp(
      safeTop,
      double.infinity,
    );
    final delta = top - top.clamp(safeTop, lowestTop);
    final scroll = Scrollable.maybeOf(widget.messageContext);
    if (scroll != null && delta != 0) {
      await scroll.position.animateTo(
        (scroll.position.pixels + delta).clamp(
          scroll.position.minScrollExtent,
          scroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    final viewport = _viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewport != null && viewport.mounted)
        viewport.reserveMessageMenuSpace(0);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BackdropGroup(
    child: GlassSurface(
      borderRadius: GlobalUI.bottomSheetBorderRadius,
      shadowOpacity: 2.5,
      gradientColors: Theme.of(context).brightness == Brightness.light
          ? const [Color(0xcceeeeee), Color(0xb3e4e4e4), Color(0xccececec)]
          : const [Color(0xcc383838), Color(0xb3282828), Color(0xcc303030)],
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(child: widget.child),
          ],
        ),
      ),
    ),
  );
}
