import 'package:aon2026/models/passport_fact.dart';

/// Release-safe fallback copy shown when a fact is still an unreviewed draft
/// in a public build (design §6.3).
const String factFallbackTitle = 'Astronomy fact awaiting review';
const String factFallbackMessage =
    'We’re confirming the learning note for this activity with the '
    'astronomy team. Your stamp is safely collected and you can come back '
    'later.';

enum FactBody { body, fallback }

/// What the fact sheet should present, decided purely from confidence + build
/// mode (design §6). Kept out of the widget so it is unit-testable.
class FactPresentation {
  const FactPresentation({required this.body, required this.showDraftNote});
  final FactBody body;
  final bool showDraftNote;
}

FactPresentation resolveFactPresentation(
  PassportFact fact, {
  required bool isRelease,
}) {
  // Visitor-facing rule (stakeholder decision): a collected stamp always reveals
  // its actual fact, and NEVER any "draft / pending review / awaiting review"
  // or confidence wording — internal review status is not a visitor concern.
  // `isRelease` is retained for the call-site/signature but no longer changes
  // what a visitor sees; the fallback path is intentionally never taken.
  return const FactPresentation(body: FactBody.body, showDraftNote: false);
}
