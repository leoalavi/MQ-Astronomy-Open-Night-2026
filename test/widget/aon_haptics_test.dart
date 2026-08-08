import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/utils/haptics.dart';

void main() {
  test('disabled haptics is a no-op and never throws', () async {
    await AonHaptics.selection(false);
    await AonHaptics.light(false);
  });
}
