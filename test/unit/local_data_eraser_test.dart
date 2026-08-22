import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/local_data_eraser.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/passport_store.dart';

const _eventId = 'aon2026';

class _ThrowingPrefs implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(StateError('platform store unavailable'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eraseAll clears every key the real stores actually write', () async {
    // `SharedPreferencesAsync` is NOT mocked with setMockInitialValues — the
    // repo's own pattern (passport_store_test.dart:44, favorites_test.dart:77)
    // swaps the platform instance. Seeded from the STORES' own constants, not
    // from retyped literals: if eraser and store ever disagree, this test fails
    // instead of lying.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsPassportStore.storageKey: <String>['obs', 'lab'],
      SharedPrefsFavoritesStore.buildingsKey: <String>['building:E7A'],
      SharedPrefsFavoritesStore.venuesKeyFor(_eventId): <String>['venue:obs'],
      SharedPrefsMapsConsentStore.storageKey: 'accepted',
    });
    final prefs = SharedPreferencesAsync();
    final eraser = SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId);

    expect(await eraser.eraseAll(), isTrue);

    expect(await prefs.getStringList(SharedPrefsPassportStore.storageKey), isNull);
    expect(await prefs.getStringList(SharedPrefsFavoritesStore.buildingsKey), isNull);
    expect(
        await prefs
            .getStringList(SharedPrefsFavoritesStore.venuesKeyFor(_eventId)),
        isNull);
    expect(await prefs.getString(SharedPrefsMapsConsentStore.storageKey), isNull);
  });

  test('preferences survive — they are settings, not user data', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      'settings.locale': 'fa',
      'settings.themeMode': 'dark',
      SharedPrefsPassportStore.storageKey: <String>['obs'],
    });
    final prefs = SharedPreferencesAsync();
    await SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId).eraseAll();

    expect(await prefs.getString('settings.locale'), 'fa',
        reason: 'wiping someone\'s language on "delete my data" is a surprise');
    expect(await prefs.getString('settings.themeMode'), 'dark');
  });

  test('favourites from a PREVIOUS event are user data too', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsFavoritesStore.venuesKeyFor('other-event'): <String>['venue:x'],
      SharedPrefsFavoritesStore.venuesKeyFor(_eventId): <String>['venue:obs'],
    });
    final prefs = SharedPreferencesAsync();
    await SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId).eraseAll();

    expect(
        await prefs
            .getStringList(SharedPrefsFavoritesStore.venuesKeyFor(_eventId)),
        isNull);
    expect(
        await prefs.getStringList(
            SharedPrefsFavoritesStore.venuesKeyFor('other-event')),
        isNull,
        reason: 'the control says "delete my data", not "delete this event\'s '
            'data" — a stale event\'s favourites are still the user\'s data');
  });

  test('the no-op eraser fails closed', () async {
    // A forgotten production override must surface as a visible failure, never
    // as a cheerful success over data that is still on the device.
    expect(await const NoopLocalDataEraser().eraseAll(), isFalse);
  });

  test('eraseAll never throws when the platform store fails', () async {
    final eraser =
        SharedPrefsLocalDataEraser(prefs: _ThrowingPrefs(), eventId: _eventId);
    expect(await eraser.eraseAll(), isFalse);
  });

  testWidgets('the real Settings control clears the SESSION, not just storage',
      (t) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsPassportStore.storageKey: <String>['obs'],
      SharedPrefsFavoritesStore.buildingsKey: <String>['building:E7A'],
    });
    final c = ProviderContainer(overrides: [
      localDataEraserProvider.overrideWithValue(SharedPrefsLocalDataEraser(
        prefs: SharedPreferencesAsync(),
        eventId: _eventId,
      )),
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.accepted),
      favoritesSnapshotProvider.overrideWithValue(const {'building:E7A'}),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(_settingsHost(c));
    await t.pumpAndSettle();
    expect(c.read(favoritesProvider).keys, isNotEmpty);

    await _tapErase(t);

    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.settingsEraseDone), findsOneWidget);
    expect(c.read(mapsConsentProvider), MapsConsent.unknown,
        reason: 'consent must be revoked in memory, not only in storage');
    expect(c.read(favoritesProvider).keys, isEmpty,
        reason: 'the live favourites notifier must be reset too');
  });

  testWidgets('a failed erase reports failure, never success', (t) async {
    final c = ProviderContainer(overrides: [
      // The fail-closed default: a forgotten override must be visible.
      localDataEraserProvider.overrideWithValue(const NoopLocalDataEraser()),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(_settingsHost(c));
    await t.pumpAndSettle();
    await _tapErase(t);

    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.settingsEraseFailed), findsOneWidget);
    expect(find.text(l.settingsEraseDone), findsNothing);
  });
}

// ---------------------------------------------------------------------------
// The shipped control, not just the service. FavoritesController and
// PassportNotifier hold live in-memory state seeded at startup, so a
// storage-only wipe leaves the session showing deleted data.
// ---------------------------------------------------------------------------

Widget _settingsHost(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: SettingsScreen(),
      ),
    );

Future<void> _tapErase(WidgetTester t) async {
  await t.scrollUntilVisible(find.byKey(const Key('settings-erase-button')), 300);
  await t.ensureVisible(find.byKey(const Key('settings-erase-button')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('settings-erase-button')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('settings-erase-confirm')));
  await t.pumpAndSettle();
}
