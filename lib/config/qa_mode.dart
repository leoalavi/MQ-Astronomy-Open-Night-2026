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
