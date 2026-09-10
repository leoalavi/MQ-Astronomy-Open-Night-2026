import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/url_opener.dart';
import 'package:aon2026/utils/bidi.dart';

/// The canonical Astronomy Open Night 2026 privacy presentation.
///
/// The same sectioned strings render inside the iOS, Android and web apps and
/// generate the semantic, JavaScript-free `web/privacy.html`. Every identity
/// value comes from [AppIdentity], so the public and in-app copies cannot drift.
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

    Widget body(String text) =>
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5));

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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: aon.contentSecondary,
                  ),
                ),
                const SizedBox(height: AonSpacing.space4),
                body(
                  l.webPrivacyIntro(
                    // Developer names are proper nouns — isolate so they stay LTR
                    // and in order inside the Persian (RTL) paragraph.
                    Bidi.isolate(AppIdentity.developers),
                    Bidi.isolate(AppIdentity.forTeam),
                  ),
                ),
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
                heading(l.webPrivacyMlKitHeading),
                body(l.webPrivacyMlKitBody),
                heading(l.webPrivacyMapsHeading),
                body(l.webPrivacyMapsBody),
                heading(l.webPrivacyAnalyticsHeading),
                body(l.webPrivacyAnalyticsBody),
                heading(l.webPrivacyRetentionHeading),
                body(l.webPrivacyRetentionBody),
                heading(l.webPrivacyContactHeading),
                body(
                  l.webPrivacyContactBody(
                    Bidi.isolate(AppIdentity.privacyContactEmail),
                    Bidi.isolate(AppIdentity.eventSupportEmail),
                    Bidi.isolate(AppIdentity.eventWebsiteUrl),
                    Bidi.isolate(AppIdentity.canonicalPrivacyUrl),
                  ),
                ),

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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: aon.contentSecondary,
                  ),
                ),
                const SizedBox(height: AonSpacing.space2),
                Text(
                  AppIdentity.copyrightLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: aon.contentTertiary,
                  ),
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
