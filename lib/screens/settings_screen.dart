import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/text_scale.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/local_data_eraser.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_preview.dart';
import 'package:aon2026/services/preview_location.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/url_opener.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/widgets/event_time_preview.dart';
import 'package:aon2026/widgets/section_header.dart';

/// Visitor settings.
///
/// ## What is deliberately absent
///
/// MQ Journey's Settings page carries account, notification, stamp-trail and
/// timetable preferences. None of those exist in this product, so none of them
/// appear here — the brief is explicit that a dead setting is worse than a
/// missing one.
///
/// Every control on this screen changes real behaviour. Anything that could
/// not be made to work is explained as information rather than offered as a
/// switch that does nothing.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final config = ref.watch(eventConfigProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      // Each section = one heading + its card(s). SectionHeader supplies the
      // 24pt gap *before* a heading; `_gap` supplies the 12pt gap *between*
      // stacked cards inside a section. Without it the zero-margin cards fuse
      // into one block (the "compressed" look this restructure fixes).
      body: ListView(
        // Bottom inset is the SHELL's clearance, not a fixed 64: the floating
        // glass tab bar is 66pt tall and sits above the home indicator, so a
        // constant smaller than that hides the last row (the Google Maps
        // licences button) behind the island. See AonNavMetrics.clearance.
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonNavMetrics.clearance(context),
        ),
        children: [
          // ── Appearance ──
          SectionHeader(
            title: l.settingsAppearance,
            icon: Icons.dark_mode_rounded,
          ),
          settings.when(
            loading: () => const _SettingSkeleton(),
            error: (_, _) => const _SettingUnavailable(),
            data: (s) => _AppearanceCard(selected: s.themeMode),
          ),

          // ── Language ──
          SectionHeader(
            title: l.settingsLanguage,
            icon: Icons.translate_rounded,
          ),
          settings.when(
            loading: () => const _SettingSkeleton(),
            error: (_, _) => const _SettingUnavailable(),
            data: (s) => _LanguageCard(selected: s.localeCode),
          ),

          // ── Motion & feedback ──
          SectionHeader(title: l.settingsMotion, icon: Icons.animation_rounded),
          settings.when(
            loading: () => const _SettingSkeleton(),
            error: (_, _) => const _SettingUnavailable(),
            data: (s) => _SwitchCard(
              value: s.reduceMotion,
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).setReduceMotion(v),
              icon: Icons.motion_photos_off_outlined,
              title: l.settingsReduceMotion,
              body: l.settingsReduceMotionBody,
            ),
          ),
          _gap,
          settings.when(
            loading: () => const _SettingSkeleton(),
            error: (_, _) => const _SettingUnavailable(),
            data: (s) => _SwitchCard(
              value: s.hapticsEnabled,
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).setHapticsEnabled(v),
              icon: Icons.vibration_rounded,
              title: l.settingsHaptics,
              body: l.settingsHapticsBody,
            ),
          ),

          // ── Text size ──
          SectionHeader(
            title: l.settingsTextSize,
            icon: Icons.format_size_rounded,
          ),
          _InfoCard(
            icon: Icons.text_fields_rounded,
            title: l.settingsTextSizeCardTitle,
            body: l.settingsTextSizeBody((kMaxTextScale * 100).round()),
          ),

          // ── Privacy ──
          SectionHeader(
            title: l.settingsPrivacy,
            icon: Icons.lock_outline_rounded,
          ),
          _InfoCard(
            icon: Icons.verified_user_outlined,
            title: l.settingsPrivacyCardTitle,
            // Every clause here is a fact about this build, not marketing.
            body: l.settingsPrivacyBody,
          ),
          _gap,
          // The one exception to "nothing leaves your phone" — surfaced
          // honestly, with a revoke control once consent has been given.
          const _GoogleMapsPrivacyCard(),

          // In-app Privacy Policy entry point (store requirement — the policy
          // must be reachable from inside the app). Shown ONLY when a real
          // hosted URL is configured (EventConfig.privacyPolicyUrl); null until
          // Macquarie hosts the page, so no dead link ships (release blocker B7).
          if (config.privacyPolicyUrl case final String policyUrl) ...[
            _gap,
            _PrivacyPolicyCard(url: policyUrl),
          ],

          // ── Your data ──
          SectionHeader(
            title: l.settingsYourData,
            icon: Icons.delete_outline_rounded,
          ),
          const _DeleteMyDataCard(),

          // ── Preview (organiser tools) ──
          //
          // Both are "see it before the night" simulations: one fakes your
          // position, the other the clock. Grouped, and kept low on the page —
          // they are review tools, not something a visitor needs on the night.
          SectionHeader(title: l.previewSection, icon: Icons.science_outlined),
          const _PreviewLocationCard(),
          _gap,
          const EventTimePreviewCard(),
          _gap,
          const _PassportPreviewCard(),

          // ── About ──
          SectionHeader(
            title: l.settingsAbout(config.name),
            icon: Icons.info_outline_rounded,
          ),
          _AboutCard(config: config),

          // ── Credits (always last) ──
          SectionHeader(
            title: l.settingsCredits,
            icon: Icons.copyright_rounded,
          ),
          _CreditsCard(config: config),
        ],
      ),
    );
  }
}

/// Consistent 12pt gap between stacked cards inside a single section.
const _gap = SizedBox(height: AonSpacing.space3);

/// A settings row that is a real toggle, in a card with a leading icon.
///
/// One widget for every on/off setting (Reduce motion, Haptics) so they are
/// visually identical and equally spaced.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.body,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space2,
        ),
      ),
    );
  }
}

/// The appearance chooser.
///
/// A real, three-way control — System / Light / Dark — because the app now
/// ships two complete themes. Dark carries a "Recommended" hint rather than
/// being forced: the event runs after sunset and a bright screen beside a
/// telescope spoils night vision, but that is guidance, not a lock.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.selected});

  final AppThemeMode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    return Card(
      // RadioGroup, not per-tile onChanged: Flutter deprecated the old
      // groupValue/onChanged pair after 3.32.
      child: RadioGroup<AppThemeMode>(
        groupValue: selected,
        onChanged: (v) {
          if (v != null) {
            ref.read(appSettingsProvider.notifier).setThemeMode(v);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final mode in AppThemeMode.values)
              RadioListTile<AppThemeMode>(
                value: mode,
                title: Text(switch (mode) {
                  AppThemeMode.system => l.settingsAppearanceSystem,
                  AppThemeMode.light => l.settingsAppearanceLight,
                  AppThemeMode.dark => l.settingsAppearanceDark,
                }),
                subtitle: mode == AppThemeMode.dark
                    ? Text(
                        l.settingsAppearanceDarkHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.aon.contentTertiary,
                        ),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AonSpacing.space4,
                  vertical: AonSpacing.space1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// In-app language picker: System / English / فارسی.
///
/// ## Why this exists as an explicit control
///
/// The app ships two complete translations, but until this card existed the
/// Persian one was only reachable by changing the whole phone's language. That
/// stranded two groups: a visitor who prefers Persian on a device shared or
/// configured in English, and anyone at the University trying to review the
/// translation before the night.
///
/// `null` means "follow the device", which is the default and stays the default
/// — an explicit choice is stored only once the visitor makes one, so a phone
/// already set to Persian opens in Persian with no interaction.
///
/// The language names are deliberately NOT translated. An endonym is the only
/// label a reader who cannot yet read the current language can recognise.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.selected});

  /// The stored language code, or null for "match my device".
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    // Null is a legitimate value here, so the group is keyed on String? and the
    // system option carries null rather than a sentinel string.
    return Card(
      child: RadioGroup<String?>(
        groupValue: selected,
        onChanged: (v) => ref.read(appSettingsProvider.notifier).setLocale(v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<String?>(
              value: null,
              title: Text(l.settingsLanguageSystem),
              subtitle: Text(
                l.settingsLanguageSystemHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.aon.contentTertiary,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AonSpacing.space4,
                vertical: AonSpacing.space1,
              ),
            ),
            RadioListTile<String?>(
              value: 'en',
              // Endonym: always "English", never translated.
              title: Text(l.settingsLanguageEnglish),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AonSpacing.space4,
                vertical: AonSpacing.space1,
              ),
            ),
            RadioListTile<String?>(
              value: 'fa',
              // Endonym: always "فارسی", never romanised.
              //
              // No explicit textDirection. An earlier version forced RTL here
              // "so it reads correctly in English", which was unnecessary — the
              // string is pure Arabic script, so bidi shapes it right-to-left
              // whatever the paragraph direction — and actively harmful: RTL
              // aligned the label to the far edge of the full-width title slot,
              // stranding it ~500pt from its own radio button. Inheriting the
              // ambient direction keeps every option aligned with its control
              // in both app languages.
              title: Text(l.settingsLanguagePersian),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AonSpacing.space4,
                vertical: AonSpacing.space1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Preview from anywhere" — a simulated on-campus position (§3c / D7).
///
/// Visible and documented, therefore not a 2.3.1(a) hidden or dormant feature.
/// Session-only and off by default, and `PreviewLocationBadge` keeps the
/// substitution visible on every screen that draws a position.
class _PreviewLocationCard extends ConsumerWidget {
  const _PreviewLocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    return Card(
      child: SwitchListTile.adaptive(
        key: const Key('settings-preview-toggle'),
        value: ref.watch(previewLocationProvider),
        onChanged: (v) => ref.read(previewLocationProvider.notifier).set(v),
        title: Text(l.settingsPreviewTitle),
        subtitle: Text(l.settingsPreviewBody),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space2,
        ),
      ),
    );
  }
}

/// Opens passport collection away from the venue signs.
///
/// It was load-bearing while the nine station codes were `AON-*-TBC`: without
/// it the Passport tab was inert in every release build — a dormant feature,
/// which guideline 2.3.1(a) forbids and which no reviewer or visitor could
/// evaluate. The real codes have landed, so the gate now opens on its own and
/// this is the try-it-anywhere control. Deliberately here, beside the other
/// preview controls, rather than behind a hidden gesture: the same reasoning
/// `PreviewLocationService` records for the simulated position.
class _PassportPreviewCard extends ConsumerWidget {
  const _PassportPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    return Card(
      child: SwitchListTile.adaptive(
        key: const Key('settings-passport-preview-toggle'),
        value: ref.watch(passportPreviewProvider),
        onChanged: (v) => ref.read(passportPreviewProvider.notifier).set(v),
        title: Text(l.settingsPassportPreviewTitle),
        subtitle: Text(l.settingsPassportPreviewBody),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space2,
        ),
      ),
    );
  }
}

/// "Delete my data" — clears everything this app stores on this device.
///
/// NOT an Apple requirement: 5.1.1(i) governs what the privacy POLICY must
/// explain, and 5.1.1(v)'s in-app deletion rule is conditional on account
/// creation, which this app has none of. It is here because the data is local,
/// so the control is cheap, transparent and testable.
///
/// Deletion is an orchestration, not a storage wipe: FavoritesController and
/// PassportNotifier hold live in-memory state seeded at startup, so clearing
/// SharedPreferences alone would leave the session showing deleted data and the
/// next save would write it straight back.
class _DeleteMyDataCard extends ConsumerWidget {
  const _DeleteMyDataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.settingsEraseTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AonSpacing.space2),
            Text(
              l.settingsEraseBody,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
            const SizedBox(height: AonSpacing.space2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('settings-erase-button'),
                onPressed: () => _confirmErase(context, ref, l),
                child: Text(l.settingsEraseConfirmAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmErase(
      BuildContext context, WidgetRef ref, AonL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: context.aon.surface,
        title: Text(l.settingsEraseConfirmTitle),
        content: Text(l.settingsEraseConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.settingsEraseCancel),
          ),
          FilledButton(
            key: const Key('settings-erase-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.settingsEraseConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Session FIRST, storage second. Both notifiers persist through a serialized
    // save chain, so erasing storage before clearing them would let a queued
    // write put the keys straight back. And `ref.invalidate` is not a
    // substitute for a clear: build() re-seeds from the startup snapshot, which
    // would restore exactly the data this control just removed.
    ref.read(passportProvider.notifier).reset();
    ref.read(favoritesProvider.notifier).clearAll();
    ref.read(mapsConsentProvider.notifier).revoke();
    await ref.read(savedEventsProvider.notifier).clear();
    await ref.read(favoritesProvider.notifier).flush();
    await ref.read(passportProvider.notifier).flush();

    final ok = await ref.read(localDataEraserProvider).eraseAll();
    if (!context.mounted) return;

    // Never claim a success we did not verify.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.settingsEraseDone : l.settingsEraseFailed),
    ));
  }
}

/// Google Maps privacy notice + sharing toggle. The ToS/privacy notice is always
/// shown. Sharing is ON unless explicitly turned OFF: "Revoke" calls `decline()`
/// (consent -> declined), after which the button flips to "Turn back on"
/// (`accept()`). Turning it off here means the next Directions tap lands on the
/// in-app sharing-off panel (a re-disclosure with a one-tap re-enable), never a
/// Google surface. (First-use consent itself is the explicit disclosure dialog on
/// the Directions path — B2, 2026-09-01; erase-my-data resets consent to unknown.)
class _GoogleMapsPrivacyCard extends ConsumerWidget {
  const _GoogleMapsPrivacyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final consent = ref.watch(mapsConsentProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: AonSpacing.iconMd,
                  color: context.aon.accent,
                ),
                const SizedBox(width: AonSpacing.space3),
                Expanded(
                  child: Text(
                    l.settingsGoogleMapsNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.contentSecondary,
                    ),
                  ),
                ),
              ],
            ),
            // First-use consent is the explicit disclosure on the Directions
            // path (B2); this card is the standing opt-out. Sharing is ON unless
            // explicitly turned OFF (declined): "Revoke" turns it off; once off,
            // "Turn back on" re-enables.
            const SizedBox(height: AonSpacing.space2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: consent == MapsConsent.declined
                  ? TextButton(
                      key: const Key('settings-enable-google-consent'),
                      onPressed: () =>
                          ref.read(mapsConsentProvider.notifier).accept(),
                      child: Text(l.settingsEnableGoogleConsent),
                    )
                  : TextButton(
                      key: const Key('settings-revoke-google-consent'),
                      onPressed: () =>
                          ref.read(mapsConsentProvider.notifier).decline(),
                      child: Text(l.settingsRevokeGoogleConsent),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The in-app Privacy Policy link. Opens the hosted policy in the browser; if
/// the browser cannot open it, says so honestly rather than doing nothing.
class _PrivacyPolicyCard extends ConsumerWidget {
  const _PrivacyPolicyCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    return Card(
      child: ListTile(
        key: const Key('settings-privacy-policy'),
        leading: Icon(Icons.policy_outlined, color: context.aon.accent),
        title: Text(l.settingsPrivacyPolicy),
        trailing: const Icon(Icons.open_in_new_rounded),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space1,
        ),
        onTap: () async {
          final opener = ref.read(urlOpenerProvider);
          final ok = await opener(Uri.parse(url));
          if (!context.mounted || ok) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.settingsPrivacyPolicyUnavailable)),
          );
        },
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.config});

  final EventConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AonSpacing.space2),
            Text(
              '${TimeFormat.longDate(config.startsAt)}\n'
              '${TimeFormat.range(config.startsAt, config.endsAt)}\n'
              '${config.host}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.config});

  final EventConfig config;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodySmall?.copyWith(
      color: context.aon.contentSecondary,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.settingsCreditsHeroImage, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(config.heroCredit, style: body),
            const SizedBox(height: AonSpacing.space4),
            Text(
              l.settingsCreditsEventMaterials,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              l.creditsEventMaterialsBody(
                config.host,
                config.faculty,
                EventInfo.cricosProvider,
              ),
              style: body,
            ),
            const SizedBox(height: AonSpacing.space4),
            Text(l.settingsCreditsMapData, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(l.settingsMapDataAttribution, style: body),
            const Divider(height: AonSpacing.space6),
            Text(l.settingsCreditsDevelopers, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            // Names are proper nouns — isolate them so they stay LTR in Persian.
            Text(
              l.creditsDevelopedBy(
                Bidi.isolate(EventInfo.developerPrimary),
                Bidi.isolate(EventInfo.developerSecondary),
              ),
              style: body,
            ),
            // Acknowledgement (Charanya-approved): frames the app as an
            // appreciation by two MQ student developers — NOT an official
            // University product. No University logo accompanies it.
            const SizedBox(height: AonSpacing.space2),
            Text(l.creditsAcknowledgement, style: body),
            // Google Maps SDK open-source licences — a legal requirement of
            // using the SDK. Static bundled text; reading it never contacts
            // Google, so it is safe to surface before consent.
            const _MapsLicenceLink(),
          ],
        ),
      ),
    );
  }
}

/// A read-only explanation. Used where a preference would be dead UI.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AonSpacing.iconMd, color: context.aon.accent),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AonSpacing.space1),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.contentSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSkeleton extends StatelessWidget {
  const _SettingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: context.aon.surface,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: context.aon.border),
      ),
    );
  }
}

class _SettingUnavailable extends StatelessWidget {
  const _SettingUnavailable();

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    return _InfoCard(
      icon: Icons.error_outline_rounded,
      title: l.settingsUnavailableTitle,
      body: l.settingsUnavailableBody,
    );
  }
}

class _MapsLicenceLink extends ConsumerWidget {
  const _MapsLicenceLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    return FutureBuilder<String?>(
      future: ref.read(mapsSdkInitializerProvider).openSourceLicenseInfo(),
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null || text.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('credits-maps-licences'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(l.creditsMapsLicences)),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(AonSpacing.space4),
                    child: SelectableText(
                      text,
                      key: const Key('maps-licence-text'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ),
            child: Text(l.creditsMapsLicences),
          ),
        );
      },
    );
  }
}

