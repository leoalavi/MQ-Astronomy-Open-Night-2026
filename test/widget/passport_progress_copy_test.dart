import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/screens/passport_screen.dart';

void main() {
  String line(bool enabled, int count) =>
      passportProgressLine(collectionEnabled: enabled, count: count, total: 9);

  test('disabled overrides in-progress states', () {
    expect(line(false, 0), 'Astronomy Passport opens on event night');
    expect(line(false, 3), 'Astronomy Passport opens on event night');
  });
  test('completion outranks the disabled gate (persisted 9/9)', () {
    expect(line(false, 9), '9 / 9 stamps'); // NOT "opens on event night"
    expect(line(true, 9), '9 / 9 stamps');
  });
  test('boundaries', () {
    expect(line(true, 0), 'Scan or enter a venue code to start');
    expect(line(true, 1), '1 / 9 stamps');
    expect(line(true, 7), '7 / 9 stamps');
    expect(line(true, 8), 'Just 1 more to go!');
    expect(line(true, 9), '9 / 9 stamps');
  });
}
