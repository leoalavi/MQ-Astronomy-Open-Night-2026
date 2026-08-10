import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/main.dart';
import 'package:aon2026/services/passport_store.dart';

class _ThrowingStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => throw StateError('disk gone');
  @override
  Future<bool> save(Set<String> v) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadPassport swallows a store failure -> empty snapshot, never throws',
      () async {
    final (snapshot, store) = await loadPassport(store: _ThrowingStore());
    expect(snapshot, isEmpty);
    expect(store, isA<PassportStore>());
  });
}
