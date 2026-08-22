import 'package:flutter/services.dart';

/// Astronomy Open Night haptic feedback wrapper.
///
/// Respects the user's "Haptic Feedback" preference.
abstract final class AonHaptics {
  /// App-wide haptics master switch, mirrored from the "Haptics" setting.
  ///
  /// A static synced from `appSettingsProvider` in the app root — the same
  /// pattern as `TimeFormat.locale` — so every call site respects the toggle
  /// without threading a provider through shared widgets (including the ones
  /// the passport feature owns). Defaults on; a per-call `isEnabled: false`
  /// still wins, so a control that opts out of haptics stays silent regardless.
  static bool globalEnabled = true;

  static bool _on(bool isEnabled) => isEnabled && globalEnabled;

  /// Triggers a light impact vibration if enabled.
  static Future<void> light(bool isEnabled) async {
    if (_on(isEnabled)) await HapticFeedback.lightImpact();
  }

  /// Triggers a medium impact vibration if enabled.
  static Future<void> medium(bool isEnabled) async {
    if (_on(isEnabled)) await HapticFeedback.mediumImpact();
  }

  /// Triggers a heavy impact vibration if enabled.
  static Future<void> heavy(bool isEnabled) async {
    if (_on(isEnabled)) await HapticFeedback.heavyImpact();
  }

  /// Triggers a selection click vibration if enabled.
  static Future<void> selection(bool isEnabled) async {
    if (_on(isEnabled)) await HapticFeedback.selectionClick();
  }
}
