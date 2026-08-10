import 'package:aon2026/models/data_confidence.dart';
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
  // confirmed/derived: publishable body, no note.
  if (fact.confidence.isReliable) {
    return const FactPresentation(body: FactBody.body, showDraftNote: false);
  }
  // placeholder: release hides the draft (safe fallback); debug shows it + note.
  return isRelease
      ? const FactPresentation(body: FactBody.fallback, showDraftNote: false)
      : const FactPresentation(body: FactBody.body, showDraftNote: true);
}
