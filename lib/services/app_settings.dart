import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/utils/haptics.dart';

/// Visitor preferences.
///
/// Deliberately short. The brief is explicit that a dead setting is worse than
/// a missing one, so this holds only preferences the app genuinely acts on:
///
/// * [themeMode] — read by `AonApp`
/// * [reduceMotion] — read by the glass/tab-bar animations
/// * [locale] — read by `MaterialApp.locale`
///
/// Things intentionally **not** here: notification preferences (the app sends
/// none), account settings (there are no accounts), analytics opt-out (nothing
/// is collected), and map-layer defaults (the map's own filter bar is a better
/// place for those, and it already persists nothing by design).
@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.reduceMotion,
    this.hapticsEnabled = true,
    this.localeCode,
  });

  final AppThemeMode themeMode;

  /// Honours the OS "reduce motion" switch when false; when true, forces
  /// reduced motion regardless. The app never *increases* motion beyond what
  /// the OS allows.
  final bool reduceMotion;

  /// Whether tactile controls fire a small vibration. On by default; some
  /// visitors (and some phones) are better without it. Brought over from MQ
  /// Journey's accessibility settings — see [AonHaptics].
  final bool hapticsEnabled;

  /// `null` follows the device language.
  final String? localeCode;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? reduceMotion,
    bool? hapticsEnabled,
    String? localeCode,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
    );
  }
}

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _kThemeMode = 'settings.themeMode';
  static const _kReduceMotion = 'settings.reduceMotion';
  static const _kHaptics = 'settings.hapticsEnabled';
  static const _kLocale = 'settings.locale';

  @override
  Future<AppSettings> build() async {
    final defaultMode = ref.watch(eventConfigProvider).defaultThemeMode;
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      // The event config supplies the default (dark for a night event); the
      // stored value wins once the visitor has chosen for themselves.
      themeMode: prefs.containsKey(_kThemeMode)
          ? AppThemeMode.fromName(prefs.getString(_kThemeMode))
          : defaultMode,
      reduceMotion: prefs.getBool(_kReduceMotion) ?? false,
      hapticsEnabled: prefs.getBool(_kHaptics) ?? true,
      localeCode: prefs.getString(_kLocale),
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = AsyncData((state.value ?? _fallback).copyWith(themeMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setReduceMotion(bool value) async {
    state =
        AsyncData((state.value ?? _fallback).copyWith(reduceMotion: value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceMotion, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    state =
        AsyncData((state.value ?? _fallback).copyWith(hapticsEnabled: value));
    // Apply to the master switch NOW rather than waiting for `AonApp.build` to
    // mirror it on the next frame. The switch's own confirming tick fires
    // inside this turn, so a stale static would invert it: turning haptics ON
    // would be silent and turning them OFF would still buzz — which reads
    // exactly like the "haptics are broken" report this fix answers.
    AonHaptics.globalEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, value);
  }

  /// `null` restores "follow device language".
  Future<void> setLocale(String? code) async {
    state = AsyncData(
      (state.value ?? _fallback)
          .copyWith(localeCode: code, clearLocale: code == null),
    );
    final prefs = await SharedPreferences.getInstance();
    code == null
        ? await prefs.remove(_kLocale)
        : await prefs.setString(_kLocale, code);
  }

  AppSettings get _fallback => AppSettings(
        themeMode: ref.read(eventConfigProvider).defaultThemeMode,
        reduceMotion: false,
      );
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

/// The resolved theme mode.
///
/// Falls back to the event default while the stored value loads, so the app
/// never flashes light before settling on dark — which at a night event would
/// be a genuinely unpleasant first frame.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(appSettingsProvider).value?.themeMode ??
      ref.watch(eventConfigProvider).defaultThemeMode;
});

/// Whether animations should be reduced — the app setting OR the OS setting.
final reduceMotionProvider = Provider<bool>(
  (ref) => ref.watch(appSettingsProvider).value?.reduceMotion ?? false,
);

/// Whether tactile controls should vibrate. Defaults on while settings load.
final hapticsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appSettingsProvider).value?.hapticsEnabled ?? true,
);

/// The app's locale override, or null to follow the device.
///
/// `MaterialApp.locale` treats null as "use the platform locale", which is
/// exactly the behaviour we want for the default, so no special-casing is
/// needed at the call site.
final localeProvider = Provider<Locale?>((ref) {
  final code = ref.watch(appSettingsProvider).value?.localeCode;
  return code == null ? null : Locale(code);
});
