import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/url_opener.dart';
import 'package:aon2026/utils/bidi.dart';

/// The Astronomy Open Night 2026 **web** privacy page.
///
/// Reachable at `/privacy` — under the app's `/astronomy-open-night/` base href
/// that is `…/astronomy-open-night/privacy`, the canonical hosted address. It
/// deliberately does NOT reuse the native `settingsPrivacyPolicyBody`, which is
/// Play/Android-specific (it names Google Play publication, ML Kit and Android
/// backups). This page describes what the *web* build actually does: browser
/// localStorage, browser geolocation, manual passport codes (no camera), and
/// Google Maps only after consent. Every identity string comes from
/// [AppIdentity] so the publisher/owner framing stays configurable and correct.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final aon = context.aon;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(
            top: AonSpacing.space6,
            bottom: AonSpacing.space2,
          ),
          // Semantics.header so screen readers announce these as headings and
          // users can jump between them.
          child: Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleMedium),
          ),
        );

    Widget body(String text) => Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.webPrivacyTitle)),
      body: SafeArea(
        child: Center(
          // Cap the measure on wide desktop browsers — a full-width wall of
          // legal text is unreadable. Phones use the whole width.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AonSpacing.space5,
                vertical: AonSpacing.space5,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.webPrivacyPageTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  l.webPrivacyLastUpdated(AppIdentity.privacyLastUpdated),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: aon.contentSecondary),
                ),
                const SizedBox(height: AonSpacing.space4),
                body(l.webPrivacyIntro(
                  // Developer names are proper nouns — isolate so they stay LTR
                  // and in order inside the Persian (RTL) paragraph.
                  Bidi.isolate(AppIdentity.developers),
                  Bidi.isolate(AppIdentity.forTeam),
                )),
                const SizedBox(height: AonSpacing.space3),
                // Scope: this policy is specific to this app and covers no other
                // site or application.
                body(l.webPrivacyScope),

                heading(l.webPrivacyStorageHeading),
                body(l.webPrivacyStorageBody),
                heading(l.webPrivacyLocationHeading),
                body(l.webPrivacyLocationBody),
                heading(l.webPrivacyCameraHeading),
                body(l.webPrivacyCameraBody),
                heading(l.webPrivacyMapsHeading),
                body(l.webPrivacyMapsBody),
                heading(l.webPrivacyAnalyticsHeading),
                body(l.webPrivacyAnalyticsBody),
                heading(l.webPrivacyRetentionHeading),
                body(l.webPrivacyRetentionBody),
                heading(l.webPrivacyContactHeading),
                body(l.webPrivacyContactBody),

                const SizedBox(height: AonSpacing.space4),
                // This screen IS the canonical policy (…/privacy on the app's
                // own host), so it links out only to the official event site.
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final opener = ref.read(urlOpenerProvider);
                    await opener(Uri.parse(AppIdentity.eventWebsiteUrl));
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l.infoOfficialWebsite),
                ),

                const Divider(height: AonSpacing.space8),
                Text(
                  l.webPrivacyCredit(
                    Bidi.isolate(AppIdentity.developers),
                    Bidi.isolate(AppIdentity.forTeam),
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: aon.contentSecondary),
                ),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  AppIdentity.copyrightLine,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: aon.contentTertiary),
                ),
                const SizedBox(height: AonSpacing.space6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
