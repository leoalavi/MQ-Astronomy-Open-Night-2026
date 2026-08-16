import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/nav_format.dart';

void main() {
  late AonL10n l;
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l = await AonL10n.delegate.load(const Locale('en'));
  });

  test('distance: <1000 → metres; ≥1000 → km one decimal', () {
    expect(formatNavDistance(l, 412), '412 m');
    expect(formatNavDistance(l, 999), '999 m');
    expect(formatNavDistance(l, 1000), '1.0 km');
    expect(formatNavDistance(l, 1449), '1.4 km');
    expect(formatNavDistance(l, 1460), '1.5 km'); // one-decimal rounding
  });

  test('eta: <60 min → min; ≥60 → hr + min', () {
    expect(formatNavEta(l, const Duration(seconds: 350)), '6 min'); // round(350/60)=6
    expect(formatNavEta(l, const Duration(minutes: 59)), '59 min');
    expect(formatNavEta(l, const Duration(minutes: 60)), '1 hr 0 min');
    expect(formatNavEta(l, const Duration(minutes: 64)), '1 hr 4 min');
  });
}
