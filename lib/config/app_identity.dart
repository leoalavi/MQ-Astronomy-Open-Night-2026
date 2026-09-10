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
/// ## The identity model (owner-confirmed)
///
/// Astronomy Open Night 2026 is an **independent event companion app**. It is
/// developed by **Leo Alavi and Mohammad Raouf Abedini** for the **Astronomy
/// Night – FSE Outreach Team**. Official event information and support are
/// provided through the Macquarie University Astronomy Open Night website.
///
/// It is **not** a Syllabus Sync product and is **not** part of any "Syllabus
/// Sync ecosystem". The `syllabus-sync.app` domain is used **only as hosting
/// infrastructure** (this app is served from the `aon.syllabus-sync.app`
/// subdomain). The domain must never be presented as evidence of ownership or
/// affiliation, and "Syllabus Sync" must never appear as the developer,
/// publisher, owner or product family of this app.
///
/// Rules encoded here, not to be undone lightly:
/// * The developers are [developers]. They are **not** the event owner.
/// * The copyright holder is the event team ([copyrightLine]) — never
///   "© Macquarie University" and never a developer's name.
/// * Support/contact routes to the official Macquarie University event website,
///   never to a personal or university-impersonating address.
abstract final class AppIdentity {
  /// Who built the app. Two individuals — not a company or "team" brand.
  static const String developers = 'Leo Alavi and Mohammad Raouf Abedini';

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

  /// Privacy and developer enquiries.
  static const String privacyContactEmail = 'leo@leoalavi.dev';

  /// Official event information and visitor support.
  static const String eventSupportEmail = 'astronomyopennight@mq.edu.au';

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
