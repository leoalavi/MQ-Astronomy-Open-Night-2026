/// Product identity, official links and copyright wording — in ONE place.
///
/// ## Why this exists (read before changing any value)
///
/// `docs/release/hosted-pages.md` is emphatic that the app's identity must
/// never be guessed and must never present a university as the publisher. The
/// web build surfaces an identity in several places — the in-app Privacy page,
/// the Info screen's official-website link, and the footer credit — and every
/// one reads from here, so the identity can be corrected in a single edit and
/// can never drift between screens.
///
/// ## The identity model (event team, 2026-09-09, reaffirmed 2026-09-10)
///
/// Each party is named for exactly what it does:
///
/// * **Leo Alavi** holds the store developer account and is the App Store
///   seller of record.
/// * **The Syllabus Sync team** — Leo Alavi and Mohammad Raouf Abedini —
///   developed the app. This is the credit the event team asked for, and both
///   names stay with it.
/// * **Astronomy Night – FSE Outreach Team** runs the event and holds the
///   copyright.
/// * **The Macquarie University event site** is the official event and support
///   source, alongside the event team's own address.
/// * **The `syllabus-sync.app` domain** is the technical host of this app and
///   its privacy policy (served at `aon.syllabus-sync.app`), and nothing more.
///
/// The app is therefore **not** a Syllabus Sync product and **not** part of any
/// "Syllabus Sync ecosystem", even though the Syllabus Sync team built it. Both
/// statements are true together and both must stay on the page. The domain must
/// never be presented as evidence of ownership, and "Syllabus Sync" must never
/// appear as the **publisher, owner or product family** of this app.
///
/// An earlier revision of this file removed the team credit entirely and made
/// the developers two unaffiliated individuals. The event team rejected that
/// wording on 2026-09-10 and restored the credit above; do not re-remove it.
///
/// Rules encoded here, not to be undone lightly:
/// * The developers are [developers]. They are **not** the event owner.
/// * The copyright holder is the event team ([copyrightLine]) — never
///   "© Macquarie University" and never a developer's name.
/// * Event support routes to the official event website. App privacy questions
///   use the publisher contact recorded in the store declarations.
abstract final class AppIdentity {
  /// Who built the app, named individually.
  static const String developers = 'Leo Alavi and Mohammad Raouf Abedini';

  /// The developer credit as the event team asked for it: the team, with both
  /// individuals named. Never shorten it to one half.
  static const String developerCredit =
      'the Syllabus Sync team ($developers)';

  /// The event team's own contact address, supplied 2026-09-09. Event questions
  /// only — app privacy and data requests use the developer account holder.
  static const String eventContactEmail = 'astronomyopennight@mq.edu.au';

  /// The event team the app is built *for* (the "for" party). Uses an en dash.
  static const String forTeam = 'Astronomy Night – FSE Outreach Team';

  /// The copyright holder — the event team, using an en dash to match [forTeam].
  /// **Never** "© Macquarie University", and never a developer's name.
  static const String copyrightHolder = 'Astronomy Night – FSE Outreach Team';

  /// The event's year, used only for the copyright line.
  static const String copyrightYear = '2026';

  /// The full copyright line as rendered. Kept as one string so an owner who
  /// wants a different exact format changes it here and nowhere else.
  static const String copyrightLine = '© $copyrightYear $copyrightHolder';

  /// Official event information and support (Macquarie University event site).
  /// This is the single canonical support/contact destination — it deliberately
  /// stays on the university's own domain and is unrelated to where the app is
  /// hosted.
  static const String eventWebsiteUrl =
      'https://event.mq.edu.au/astronomy-open-night/';

  /// Where the app is hosted. A dedicated subdomain used purely as technical
  /// hosting infrastructure — NOT a statement of ownership or affiliation, and
  /// NOT the Syllabus Sync platform, Sylla or an "ecosystem". The app is served
  /// at the ROOT of this origin.
  static const String hostedOrigin = 'https://aon.syllabus-sync.app';

  /// The app is served at the domain root, so the web build uses `--base-href /`.
  static const String appBasePath = '/';

  /// Full canonical URLs (single source of truth for SEO/OG and docs).
  static const String canonicalAppUrl = '$hostedOrigin/';

  /// The canonical Privacy Policy — this app's own `/privacy` page at the root
  /// host. It is the address used for the App Store and Google Play privacy
  /// fields.
  static const String canonicalPrivacyUrl = '$hostedOrigin/privacy';

  /// Last review date shown on the web Privacy page. Configurable on purpose.
  static const String privacyLastUpdated = '10 September 2026';
}
