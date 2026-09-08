import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/main.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

/// `TimeFormat.locale` must never disagree with the locale the UI is rendering.
///
/// ## The bug this file exists to prevent
///
/// Pouya sent a screenshot on 2026-09-08 showing an English screen with Persian
/// times and Persian digits in it — "Previewing ۴ب.ظ. on event night",
/// "Happening now ۲", "Up next ۱۴". Not a translation gap: the *strings* were
/// English and correct. `intl` was simply still formatting for `fa`.
///
/// The cause was where `TimeFormat.locale` got assigned. It used to be a side
/// effect inside `localeResolutionCallback`, and that callback does not run on
/// every locale change. In `LocalizationsResolver.locale`:
///
/// ```dart
/// final Locale appLocale = _locale != null
///     ? _resolveLocales(<Locale>[_locale!], supportedLocales)  // callback runs
///     : _resolvedLocale!;                                      // cached!
/// ```
///
/// With an explicit override ("English"/"Persian") the callback runs on every
/// read. On **"Match my device"** `MaterialApp.locale` is null, the getter
/// returns a cached `_resolvedLocale`, and the callback is never consulted
/// again. So Persian → Match my device left the static pinned at `fa` while
/// the whole UI went back to English.
///
/// The fix reads the RESOLVED locale in `MaterialApp.builder` instead, which
/// cannot go stale because it rebuilds whenever the resolution changes. These
/// tests drive the real `AonApp` through the exact sequence.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TimeFormat.locale = null;
  });

  /// Pumps the production app root against a container the test can drive.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    // The device speaks English, so "Match my device" must resolve to `en`.
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AonApp()),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  /// The locale the widget tree is actually rendering in.
  String renderedLocale(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(LiquidTabBar)))
          .toLanguageTag();

  testWidgets('the formatting locale follows an explicit override',
      (tester) async {
    final container = await pumpApp(tester);

    await container.read(appSettingsProvider.notifier).setLocale('fa');
    await tester.pump(const Duration(milliseconds: 400));

    expect(renderedLocale(tester), 'fa');
    expect(TimeFormat.locale, 'fa');
  });

  testWidgets(
      'returning to "Match my device" takes the formatting locale back with it',
      (tester) async {
    final container = await pumpApp(tester);

    // Persian first — this is the step that used to poison the static.
    await container.read(appSettingsProvider.notifier).setLocale('fa');
    await tester.pump(const Duration(milliseconds: 400));
    expect(TimeFormat.locale, 'fa', reason: 'precondition');

    // Back to "Match my device" (a null override, device = English).
    await container.read(appSettingsProvider.notifier).setLocale(null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(renderedLocale(tester), 'en', reason: 'precondition: UI is English');
    expect(
      TimeFormat.locale,
      'en',
      reason: 'the UI went back to English but intl stayed on fa — this is the '
          '"Previewing ۴ب.ظ. on event night" screenshot',
    );
  });

  testWidgets('and the digits follow, not just the language tag',
      (tester) async {
    final container = await pumpApp(tester);

    await container.read(appSettingsProvider.notifier).setLocale('fa');
    await tester.pump(const Duration(milliseconds: 400));
    // Extended Arabic-Indic digits, as a Persian screen should read.
    expect(TimeFormat.count(14), '۱۴');

    await container.read(appSettingsProvider.notifier).setLocale(null);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      TimeFormat.count(14),
      '14',
      reason: 'an English screen showed "Up next ۱۴"',
    );
  });
}
