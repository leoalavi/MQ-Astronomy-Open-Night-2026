import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import '../support/fake_location_service.dart';

void main() {
  test('fake streams a fix', () async {
    final f = FakeLocationService();
    final got = <UserLocationFix>[];
    final sub = f.watch().listen(got.add);
    f.emit(UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 8));
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    await sub.cancel();
  });
}
