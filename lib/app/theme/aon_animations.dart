import 'package:flutter/material.dart';

/// Astronomy Open Night motion tokens.
///
/// A small, canonical duration + curve vocabulary ported from MQ_Journey's
/// `MqAnimations` (values verbatim), preventing magic-number animation values.
/// Phase 3 consumes [fast] + [easeInOut] (the tactile button); the rest are the
/// established scale for later phases. No `adaptive` helper: reduced motion is
/// handled by consumers omitting transforms (Phase-1 D5), not `Duration.zero`.
abstract final class AonAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 350);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
}
