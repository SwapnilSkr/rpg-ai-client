import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../state/play_cubit.dart';

/// Single item displayed in an anchored compact popup menu.
class AnchoredMenuItem {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  const AnchoredMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });
}

/// Compact popup surface styled in EverloreTheme (void2/void3, hairline border,
/// rounded corners, soft shadow).
class AnchoredMenuPopup extends StatelessWidget {
  final List<AnchoredMenuItem> items;
  final double width;
  final BuildContext dialogContext;

  const AnchoredMenuPopup({
    super.key,
    required this.items,
    required this.dialogContext,
    this.width = 188.0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.22),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    color: EverloreTheme.white10,
                    height: 1,
                    thickness: 1,
                  ),
                _PopupItemTile(item: items[i], dialogContext: dialogContext),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupItemTile extends StatelessWidget {
  final AnchoredMenuItem item;
  final BuildContext dialogContext;

  const _PopupItemTile({
    required this.item,
    required this.dialogContext,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        item.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item.icon,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: EverloreTheme.ui(
                  size: 13.5,
                  color: item.labelColor ?? EverloreTheme.parchment,
                  weight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the menu items for turn media actions ("Picture this" and "Film this").
List<AnchoredMenuItem> buildTurnMediaMenuItems({
  required PlayCubit cubit,
  required String eventId,
}) {
  return [
    AnchoredMenuItem(
      icon: const Icon(
        Icons.auto_awesome_rounded,
        color: EverloreTheme.goldGlow,
        size: 16,
      ),
      label: 'Picture this',
      onTap: () => cubit.requestPicture(eventId),
    ),
    AnchoredMenuItem(
      icon: const Icon(
        Icons.videocam_outlined,
        color: EverloreTheme.cyanBright,
        size: 16,
      ),
      label: 'Film this',
      onTap: () => cubit.requestTurnVideo(eventId),
    ),
  ];
}

/// Opens the anchored popup menu with "Picture this" and "Film this" for [eventId].
Future<void> showTurnMediaMenu({
  required BuildContext context,
  required PlayCubit cubit,
  required String eventId,
  Rect? anchorRect,
  double? composerTop,
}) {
  return showAnchoredMenu<void>(
    context: context,
    anchorRect: anchorRect,
    composerTop: composerTop,
    items: buildTurnMediaMenuItems(cubit: cubit, eventId: eventId),
  );
}

/// Computes the exact screen layout for an anchored menu popup.
///
/// Places at the box's bottom-right corner when room is available below;
/// otherwise flips to top-right corner.
/// Bounds are clipped against safe area and composer.
class AnchoredMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchorRect;
  final EdgeInsets safeArea;
  final double? composerTop;

  const AnchoredMenuLayoutDelegate({
    required this.anchorRect,
    required this.safeArea,
    this.composerTop,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final topBound = safeArea.top + 8.0;
    final bottomBound = (composerTop ?? (size.height - safeArea.bottom)) - 8.0;
    final leftBound = safeArea.left + 8.0;
    final rightBound = size.width - safeArea.right - 8.0;

    // Visible on-screen rect of the anchor box
    final vTop = anchorRect.top.clamp(topBound, bottomBound);
    final vBottom = anchorRect.bottom.clamp(topBound, bottomBound);
    final vLeft = anchorRect.left.clamp(leftBound, rightBound);
    final vRight = anchorRect.right.clamp(leftBound, rightBound);
    final visibleRect = Rect.fromLTRB(
      vLeft,
      vTop,
      vRight,
      math.max(vTop, vBottom),
    );

    final spaceBelow = bottomBound - visibleRect.bottom;
    final fitsBelow = spaceBelow >= childSize.height + 4.0;

    double y;
    if (fitsBelow) {
      y = visibleRect.bottom + 4.0;
    } else {
      // Flips to top-right corner
      y = visibleRect.top - childSize.height - 4.0;
      if (y < topBound) {
        // When the box is taller than the screen or top is clipped, anchor
        // to the top of the visible part inside bounds
        if (visibleRect.top + 4.0 + childSize.height <= bottomBound) {
          y = visibleRect.top + 4.0;
        } else {
          y = topBound;
        }
      }
    }

    // Anchor to right corner of visible box
    double x = visibleRect.right - childSize.width;
    if (x + childSize.width > rightBound) {
      x = rightBound - childSize.width;
    }
    if (x < leftBound) {
      x = leftBound;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(AnchoredMenuLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        safeArea != oldDelegate.safeArea ||
        composerTop != oldDelegate.composerTop;
  }
}

/// Opens an anchored popup menu anchored to [anchorRect].
///
/// Tapping outside or pressing back closes the popup.
Future<T?> showAnchoredMenu<T>({
  required BuildContext context,
  required List<AnchoredMenuItem> items,
  Rect? anchorRect,
  double? composerTop,
  double width = 188.0,
}) {
  final mediaQuery = MediaQuery.of(context);
  final effectiveAnchor = anchorRect ??
      (context.findRenderObject() is RenderBox
          ? ((context.findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero) &
              (context.findRenderObject() as RenderBox).size)
          : Rect.fromCenter(
              center: Offset(
                mediaQuery.size.width / 2,
                mediaQuery.size.height / 2,
              ),
              width: 0,
              height: 0,
            ));

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogCtx, anim1, anim2) {
      return CustomSingleChildLayout(
        delegate: AnchoredMenuLayoutDelegate(
          anchorRect: effectiveAnchor,
          safeArea: mediaQuery.padding,
          composerTop: composerTop,
        ),
        child: AnchoredMenuPopup(
          items: items,
          width: width,
          dialogContext: dialogCtx,
        ),
      );
    },
    transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: anim,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
}
