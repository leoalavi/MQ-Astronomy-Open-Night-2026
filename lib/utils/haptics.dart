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

  /// The standard feedback for pressing an ordinary button.
  ///
  /// ## Why this exists
  ///
  /// Until 2026-09-08 only five widget types ever called into this class —
  /// [AonTactileButton] (cards, quick links, passport tiles), the tab bar, the
  /// save button and the passport scanner. Every plain Material button in the
  /// app — Directions, Show on map, Walk there, every switch, radio and filter
  /// — was silent, while the Settings screen promised "a gentle vibration when
  /// you tap buttons". Pouya tested the app end to end and reported haptics as
  /// simply broken; the plumbing was fine, the coverage was not.
  ///
  /// Prefer this over calling [light] with a literal `true` at a button call
  /// site: it names the intent, and the master switch still governs it.
  static Future<void> tap() => light(true);

  /// Feedback for changing a setting, filter or segmented selection.
  ///
  /// Lighter than [tap] on purpose — this is the platform's "value changed"
  /// tick, not a "you pressed a button" impact.
  static Future<void> select() => selection(true);
}
