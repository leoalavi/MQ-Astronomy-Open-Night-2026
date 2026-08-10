import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/router/app_router.dart';

void main() {
  test('passport route paths are defined', () {
    expect(Routes.passport, '/passport');
    expect(Routes.passportScan, '/passport/scan');
    expect(Routes.passportReward, '/passport/reward');
  });
}
