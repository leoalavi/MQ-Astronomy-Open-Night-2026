import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aon2026/services/maps_consent_store.dart';

/// Persistence for the Google Maps consent answer.
///
/// The invariant that matters is the direction of failure: anything the store
/// cannot read as a definite answer must come back `unknown`, so the app asks
/// again rather than assuming agreement it was never given.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPrefsMapsConsentStore freshStore() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    return SharedPrefsMapsConsentStore(prefs: SharedPreferencesAsync());
  }

  test('an unanswered device reads as unknown', () async {
    expect(await freshStore().loadSnapshot(), MapsConsent.unknown);
  });

  test('accepted round-trips', () async {
    final store = freshStore();
    expect(await store.save(MapsConsent.accepted), isTrue);
    expect(await store.loadSnapshot(), MapsConsent.accepted);
  });

  test('declined round-trips and is not silently upgraded', () async {
    final store = freshStore();
    expect(await store.save(MapsConsent.declined), isTrue);
    expect(await store.loadSnapshot(), MapsConsent.declined);
  });

  test('a stored value we do not recognise falls back to unknown', () async {
    // A future build could write a value this one has never heard of. Reading
    // it as anything but "ask again" would be consent the user never gave.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsMapsConsentStore.storageKey: 'maybe-later',
    });
    final store = SharedPrefsMapsConsentStore(prefs: SharedPreferencesAsync());
    expect(await store.loadSnapshot(), MapsConsent.unknown);
  });

  test('saving unknown is a real erase, not a no-op', () async {
    final store = freshStore();
    await store.save(MapsConsent.accepted);
    expect(await store.save(MapsConsent.unknown), isTrue);
    expect(await store.loadSnapshot(), MapsConsent.unknown);
  });

  group('the noop default', () {
    test('holds nothing and always re-asks', () async {
      const store = NoopMapsConsentStore();
      expect(await store.loadSnapshot(), MapsConsent.unknown);
      expect(await store.save(MapsConsent.accepted), isTrue);
      expect(await store.loadSnapshot(), MapsConsent.unknown);
    });
  });

  group('consentNeedsDisclosure', () {
    test('only an explicit accept skips the disclosure', () {
      expect(consentNeedsDisclosure(MapsConsent.accepted), isFalse);
      expect(consentNeedsDisclosure(MapsConsent.unknown), isTrue);
      // A previous "no" is not a permanent brick: tapping again is asking to
      // reconsider, so the disclosure is shown rather than the tap ignored.
      expect(consentNeedsDisclosure(MapsConsent.declined), isTrue);
    });
  });
}
