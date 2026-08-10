import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:aon2026/services/passport_store.dart';

class InMemoryPassportStore implements PassportStore {
  InMemoryPassportStore([Set<String>? initial]) : _data = {...?initial};
  Set<String> _data;
  bool failNextSave = false;

  @override
  Future<Set<String>> loadSnapshot() async => {..._data};

  @override
  Future<bool> save(Set<String> v) async {
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    _data = {...v};
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fake contract: save/load round-trips; failed save is non-fatal',
      () async {
    final s = InMemoryPassportStore();
    expect(await s.save({'a', 'b'}), isTrue);
    expect(await s.loadSnapshot(), {'a', 'b'});
    s.failNextSave = true;
    expect(await s.save({'a', 'b', 'c'}), isFalse);
    expect(await s.loadSnapshot(), {'a', 'b'}); // prior data intact
  });

  test('real SharedPrefsPassportStore round-trips via in-memory platform',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = SharedPrefsPassportStore(SharedPreferencesAsync());
    expect(await store.loadSnapshot(), isEmpty);
    expect(
      await store.save({'macquarie-theatre', 'mason-theatre'}),
      isTrue,
    );
    expect(
      await store.loadSnapshot(),
      {'macquarie-theatre', 'mason-theatre'},
    );
  });
}
