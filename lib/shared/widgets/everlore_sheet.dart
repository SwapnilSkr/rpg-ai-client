import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';
import '../../app/layout/responsive.dart';

/// Presents a modal sheet the way every sheet in the app should behave.
///
/// Two things every hand-rolled `showModalBottomSheet` call got wrong:
///
///  * They defaulted to the *nearest* navigator. Inside the shell that is the
///    tab's own navigator, so the floating nav bar drew on top of the sheet
///    and stayed tappable — you could switch tabs with a modal open, and the
///    sheet was still sitting there when you came back.
///  * Their grab handles were decoration. The pill was painted inside the
///    sheet's scroll view, which swallows vertical drags, so there was no
///    part of the sheet you could actually pull down.
///
/// Presenting on the root navigator fixes the first; [SheetGrabHandle] fixes
/// the second.
Future<T?> showEverloreSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor ?? EverloreTheme.void2,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: builder,
  );
}

/// The pull-down grip at the top of a sheet.
///
/// Drags are handled here rather than relying on the sheet's own drag: most of
/// these sheets are a single scroll view, and a scrollable eats the gesture
/// before the sheet ever sees it. A deliberate pull (or a flick) closes the
/// sheet; a small movement springs back, so a form's contents are not thrown
/// away by a stray touch.
class SheetGrabHandle extends StatefulWidget {
  /// Called instead of popping, when the host needs to confirm or clean up.
  final VoidCallback? onDismiss;

  const SheetGrabHandle({super.key, this.onDismiss});

  @override
  State<SheetGrabHandle> createState() => _SheetGrabHandleState();
}

class _SheetGrabHandleState extends State<SheetGrabHandle> {
  static const _closeAfter = 64.0;
  double _pulled = 0;

  void _close() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dismiss',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _pulled += d.delta.dy,
        onVerticalDragEnd: (d) {
          final flicked = d.velocity.pixelsPerSecond.dy > 700;
          final pulled = _pulled > _closeAfter;
          _pulled = 0;
          if (flicked || pulled) _close();
        },
        onVerticalDragCancel: () => _pulled = 0,
        child: SizedBox(
          // A real grip: the pill alone is a 4pt target nobody can hit.
          height: 26,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EverloreTheme.goldDim.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard frame for a sheet's contents: grab handle, a body that scrolls
/// when it has to, and an optional pinned footer.
///
/// The height cap is the point of it. A sheet whose content is a plain column
/// is silently clipped the moment the screen is short enough — which is how a
/// 4" phone lost the bottom of the create chooser, and how the keyboard cut
/// the bottom off form sheets.
class SheetFrame extends StatelessWidget {
  final Widget child;

  /// Stays put while [child] scrolls — the save button, usually.
  final Widget? footer;
  final EdgeInsets padding;
  final VoidCallback? onDismiss;

  const SheetFrame({
    super.key,
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final layout = EvLayout.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: layout.maxSheetHeight,
          minWidth: double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetGrabHandle(onDismiss: onDismiss),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: padding.left,
                  right: padding.right,
                  top: padding.top,
                  // Lift the body clear of the keyboard rather than letting it
                  // sit underneath.
                  bottom: padding.bottom + layout.bottomInset,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  8,
                  padding.right,
                  padding.bottom,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
