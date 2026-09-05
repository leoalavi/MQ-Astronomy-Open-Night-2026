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

  // New visitor-facing contract: a collected stamp always reveals its real fact
  // and never any draft / awaiting-review wording — in every build, for every
  // confidence. Internal review status must never reach a visitor.
  test('placeholder shows the real body and NEVER a draft note (any build)',
      () {
    for (final release in [true, false]) {
      final p = resolveFactPresentation(
          _fact(DataConfidence.placeholder), isRelease: release);
      expect(p.body, FactBody.body);
      expect(p.showDraftNote, isFalse);
    }
  });
}
