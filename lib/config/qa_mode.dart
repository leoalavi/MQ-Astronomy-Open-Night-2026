import 'package:flutter_riverpod/flutter_riverpod.dart';

/// QA-only relaxations, off by default and compiled out of a normal build.
///
/// ## Why this exists
///
/// The production rule is that in-app walking directions are campus-only: an
/// origin or destination outside the Macquarie University extent is refused, so
/// the app can never route a visitor on a kilometres-long walk in from an
/// arbitrary Sydney address. That rule is correct on the night and completely
/// untestable beforehand — a developer sitting at home is, by definition,
/// off campus, so every Directions tap answers "available once you are on
/// campus" and the whole flow goes unexercised.
///
/// Enabling this lifts the SCOPE checks only. It is deliberately narrow:
///
/// * walking-only is unaffected — there is still no other travel mode anywhere
/// * Google remains the only provider
/// * consent, key gating and error handling are untouched
///
/// Enable per-run, never by editing a default:
///
/// ```
/// flutter run --dart-define-from-file=.env --dart-define=AON_ALLOW_OFF_CAMPUS_TESTING=true
/// ```
///
/// A release build that does not pass the define gets `false` folded in at
/// compile time, so the production campus rule is intact and the branch is
/// stripped. `qa_mode_test` pins that default.
const bool kAllowOffCampusTesting =
    bool.fromEnvironment('AON_ALLOW_OFF_CAMPUS_TESTING');

/// Riverpod view of [kAllowOffCampusTesting], so tests can exercise BOTH modes
/// without a rebuild. Production reads the compile-time constant.
final allowOffCampusTestingProvider =
    Provider<bool>((ref) => kAllowOffCampusTesting);

/// Shows the passport's "Reset passport" app-bar action.
///
/// It used to be `kDebugMode`, which meant every debug simulator build — the
/// ones the store screenshots and the Maestro suite are captured from — showed
/// a control that does not exist in release (2026-09-06: it appeared in the
/// App Store passport screenshot). Like [kAllowOffCampusTesting] it is now an
/// explicit per-run define, `false` in every build that does not pass it:
///
/// ```
/// flutter run --dart-define=AON_PASSPORT_RESET_TOOL=true
/// ```
const bool kPassportResetTool = bool.fromEnvironment('AON_PASSPORT_RESET_TOOL');

/// Riverpod view of [kPassportResetTool]; widget tests override it to exercise
/// the reset dialog without a rebuild.
final passportResetToolProvider = Provider<bool>((ref) => kPassportResetTool);


/// Shows the provenance line under an activity ("Source: Programme p.2 — …").
///
/// `AonEvent.sourceNote` is a **data-integrity artefact**, not visitor copy:
/// `data_integrity_test` requires every event to carry one so each published
/// time can be traced back to the programme PDF or to Liz's email, and
/// `docs/data-sources.md` describes it as "the provenance link back to the
/// PDF/email". The detail screen rendered it unconditionally, so an attendee
/// opening Solar system walk read:
///
/// > Source: Liz 2026-08-31 — "Will go up on Gymnasium Road a few days before
/// > the event…" … so classified openAllNight (not an exact session).
///
/// — an organiser named, an internal email quoted, and the internal enum
/// `openAllNight` shown to the public. Found on device 2026-09-08 while
/// re-checking Pouya's report about this screen.
///
/// Same treatment as [kPassportResetTool], for the same reason: a build that
/// does not pass the define folds `false` in at compile time.
///
/// ```
/// flutter run --dart-define=AON_SHOW_SOURCE_NOTES=true
/// ```
const bool kShowSourceNotes = bool.fromEnvironment('AON_SHOW_SOURCE_NOTES');

/// Riverpod view of [kShowSourceNotes], so tests can exercise both modes.
final showSourceNotesProvider = Provider<bool>((ref) => kShowSourceNotes);
