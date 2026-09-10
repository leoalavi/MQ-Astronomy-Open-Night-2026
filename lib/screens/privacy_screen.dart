import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/url_opener.dart';
import 'package:aon2026/utils/bidi.dart';

/// The same reviewed iOS, Android and web policy used by the offline dialog.
/// Hosted HTML at the canonical /privacy URL is exported from this policy.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final aon = context.aon;

    Future<void> openLink(String url) async {
      final ok = await ref.read(urlOpenerProvider)(Uri.parse(url));
      if (!context.mounted || ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsPrivacyPolicyUnavailable)),
      );
    }

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
                body(l.settingsPrivacyPolicyBody),
                const SizedBox(height: AonSpacing.space4),
                // The hosted HTML also exposes clickable third-party policies.
                FilledButton.tonalIcon(
                  onPressed: () => openLink(AppIdentity.canonicalPrivacyUrl),
                  icon: const Icon(Icons.policy_outlined),
                  label: Text(l.webPrivacyPublishedLinkLabel),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => openLink(AppIdentity.eventWebsiteUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l.infoOfficialWebsite),
                ),

                const Divider(height: AonSpacing.space8),
                Text(
                  l.webPrivacyCredit(
                    // The credit under the policy must match the credit inside
                    // it: the team, with both developers named.
                    Bidi.isolate(AppIdentity.developerCredit),
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
