import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';

/// The grab handle for a sheet that is a [DraggableScrollableSheet].
///
/// ## Why this exists rather than `showDragHandle: true`
///
/// `AonTheme` turns Material's own drag handle on for every bottom sheet, and
/// for a plain `showModalBottomSheet` that is exactly right: the handle is a
/// child of the `BottomSheet`, so dragging it drives the `BottomSheet`'s own
/// drag — which is the gesture that sizes and dismisses it.
///
/// Two of our sheets are not plain, though. `VenueSheet` and `VenueInfoSheet`
/// put a [DraggableScrollableSheet] *inside* the modal, so there are two
/// independent drag mechanisms stacked on one another:
///
/// * the outer modal's handle drives dismissal, and
/// * the inner sheet's extent is driven **only** by its own scrollable.
///
/// Material's handle sits in the outer one. So dragging the handle up did
/// nothing at all, and the sheet could only be expanded by dragging its
/// *contents* — reported by Pouya on 2026-09-08 ("باید این سفیده رو بکشی بالا
/// اون بیاد بالا... این اتفاق نمی‌افته، باید داخل رو بکشی بالا").
///
/// The fix is to pass `showDragHandle: false` at those two call sites and make
/// the handle the first item **inside** the inner scrollable instead. It is
/// then part of the scroll view that `DraggableScrollableSheet` listens to, so
/// a drag on it grows the sheet exactly as a drag on the content does.
///
/// Geometry and colour deliberately mirror Material's `_DragHandle`
/// (a 32×4 pill inside a `kMinInteractiveDimension` tap target) so the two
/// kinds of sheet look identical to a visitor.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  /// Material's M3 default (`BottomSheetThemeData.dragHandleSize`).
  static const Size _handleSize = Size(32, 4);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      child: Center(
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              width: _handleSize.width,
              height: _handleSize.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_handleSize.height / 2),
                color: context.aon.contentTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
