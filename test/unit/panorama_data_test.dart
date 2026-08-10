import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/panorama_data.dart';

void main() {
  test('tourFor is an exact lookup — unknown venueId returns null (no path injection)', () {
    expect(PanoramaData.tourFor('macquarie-theatre'), isNotNull);
    expect(PanoramaData.tourFor('../../etc/passwd'), isNull);
    expect(PanoramaData.tourFor('does-not-exist'), isNull);
  });
}
