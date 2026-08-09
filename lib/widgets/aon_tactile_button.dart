import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/utils/haptics.dart';

/// A surface-agnostic tactile wrapper: a squishy press-in scale + a light haptic
/// on tap-down. Ported from MQ_Journey's `MqTactileButton`, with four aon2026
/// corrections: reduced motion keeps *feedback* (an instant, non-animated pressed
/// *outline*, not an opacity fade) while dropping the *motion*; one coherent
/// button-semantics node (the gesture layer is excluded from semantics); full
/// keyboard operability + a focus ring; and `borderRadius` repurposed from a
/// vestigial param to shape the outline/ring.
///
/// The caller supplies the visual surface via [child]; this widget adds only the
/// press feedback, gesture, keyboard, and semantics — no surface, no shadow.
class AonTactileButton extends StatefulWidget {
  const AonTactileButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.hapticsEnabled = true,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Fires a light haptic on tap-down when true. Present for reference-signature
  /// parity with `MqTactileButton`; feeds [AonHaptics.light].
  final bool hapticsEnabled;

  /// Shapes both the keyboard focus ring and the reduced-motion pressed outline
  /// to match the child's corners. Required: a surface-agnostic wrapper must be
  /// told its child's shape.
  final double borderRadius;

  @override
  State<AonTactileButton> createState() => _AonTactileButtonState();
}

class _AonTactileButtonState extends State<AonTactileButton> {
  bool _pressed = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
      widget.onTap();
      return null;
    }),
  };

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails _) {
    _setPressed(true);
    AonHaptics.light(widget.hapticsEnabled);
  }

  void _handleTapUp(TapUpDetails _) {
    _setPressed(false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Motion path squishes; reduced-motion path passes the child through unscaled
    // (its pressed state comes from the outline below — never an opacity fade).
    final Widget squished = reduceMotion
        ? widget.child
        : AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: AonAnimations.fast,
            curve: AonAnimations.easeInOut,
            child: widget.child,
          );

    // One foreground outline serves both instant states, contrast-safe (adds a
    // border, dims nothing): keyboard focus ring, and reduced-motion pressed state.
    // Wraps the un-scaled bounds so the normal-mode squish doesn't move it.
    final bool showOutline = _focused || (reduceMotion && _pressed);
    final Widget ringed = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: showOutline
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : const BoxDecoration(),
      child: squished,
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          actions: _actions,
          onShowFocusHighlight: (value) {
            if (mounted) setState(() => _focused = value);
          },
          mouseCursor: SystemMouseCursors.click,
          // excludeFromSemantics: the outer Semantics is the sole a11y action, so
          // the gesture layer must not emit a second (duplicate) semantic node.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: () => _setPressed(false),
            child: ringed,
          ),
        ),
      ),
    );
  }
}
