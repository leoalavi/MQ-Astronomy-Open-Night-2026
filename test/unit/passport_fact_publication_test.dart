import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/services/passport_fact_publication.dart';

PassportFact _fact(DataConfidence c) => PassportFact(
    venueId: 'v', activityLabel: 'a', title: 't', fact: 'f', confidence: c);

void main() {
  test('confirmed/derived show the body, no draft note (any build)', () {
    for (final c in [DataConfidence.confirmed, DataConfidence.derived]) {
      for (final release in [true, false]) {
        final p = resolveFactPresentation(_fact(c), isRelease: release);
        expect(p.body, FactBody.body);
        expect(p.showDraftNote, isFalse);
      }
    }
  });

  test('placeholder in RELEASE shows the fallback, never the draft', () {
    final p = resolveFactPresentation(
        _fact(DataConfidence.placeholder), isRelease: true);
    expect(p.body, FactBody.fallback);
    expect(p.showDraftNote, isFalse);
  });

  test('placeholder in DEBUG shows the draft body + the review note', () {
    final p = resolveFactPresentation(
        _fact(DataConfidence.placeholder), isRelease: false);
    expect(p.body, FactBody.body);
    expect(p.showDraftNote, isTrue);
  });
}
