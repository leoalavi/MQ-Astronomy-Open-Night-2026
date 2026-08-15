import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/heading_service.dart';
import '../support/fake_heading_service.dart';

void main() {
  test('fake streams samples', () async {
    final f = FakeHeadingService();
    final got = <HeadingSample>[];
    final sub = f.watch().listen(got.add);
    f.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 42));
    await Future<void>.delayed(Duration.zero);
    expect(got.single.availability, HeadingAvailability.available);
    expect(got.single.magneticHeadingDegrees, 42);
    await sub.cancel();
  });
}
