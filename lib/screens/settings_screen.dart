import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/text_scale.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/utils/time_format.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonSpacing.space16,
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

          // ── Motion ──
          SectionHeader(
            title: l.settingsMotion,
            icon: Icons.animation_rounded,
          ),
          settings.when(
            loading: () => const _SettingSkeleton(),
            error: (_, _) => const _SettingUnavailable(),
            data: (s) => Card(
              child: SwitchListTile.adaptive(
                value: s.reduceMotion,
                onChanged: (v) =>
                    ref.read(appSettingsProvider.notifier).setReduceMotion(v),
                title: Text(l.settingsReduceMotion),
                subtitle: const Text(
                  'Turns off the tab bar and glass animations. Your phone’s '
                  'own reduce-motion setting is always respected too.',
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AonSpacing.space4,
                  vertical: AonSpacing.space2,
                ),
              ),
            ),
          ),

          // ── Text size ──
          SectionHeader(
            title: l.settingsTextSize,
            icon: Icons.format_size_rounded,
          ),
          _InfoCard(
            icon: Icons.text_fields_rounded,
            title: 'Set text size on your phone',
            body:
                'This app follows your device text size, up to '
                '${(kMaxTextScale * 100).round()}% — every screen is tested at '
                'that size. Change it in your phone’s display or accessibility '
                'settings.',
          ),

          // ── About ──
          SectionHeader(
            title: 'About ${config.name}',
            icon: Icons.info_outline_rounded,
          ),
          _AboutCard(config: config),

          // ── Privacy ──
          SectionHeader(
            title: l.settingsPrivacy,
            icon: Icons.lock_outline_rounded,
          ),
          const _InfoCard(
            icon: Icons.verified_user_outlined,
            title: 'Nothing leaves your phone',
            // Every clause here is a fact about this build, not marketing.
            body:
                'There is no account and no sign-in. Your saved activities are '
                'stored on this device only. The app collects no analytics and '
                'tracks no location.\n\n'
                'The only thing it fetches from the internet is map imagery — '
                'unless you choose Google Maps walking directions (below).',
          ),
          // M4: the one exception to "nothing leaves your phone" — surfaced
          // honestly, with a revoke control once consent has been given.
          const _GoogleMapsPrivacyCard(),

          // ── Credits ──
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
                  AppThemeMode.system => 'Follow my phone',
                  AppThemeMode.light => 'Light',
                  AppThemeMode.dark => 'Dark',
                }),
                subtitle: mode == AppThemeMode.dark
                    ? Text(
                        'Recommended — kinder to your night vision at the '
                        'event',
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

/// Google Maps privacy notice + revoke control. The ToS/privacy notice is
/// always shown; the "Revoke" action appears only once consent has been given
/// (there's nothing to revoke otherwise). Revoking resets consent to unknown, so
/// the next Google-nav tap re-asks (T8A / #17).
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
                Icon(Icons.map_outlined, size: AonSpacing.iconMd, color: context.aon.accent),
                const SizedBox(width: AonSpacing.space3),
                Expanded(
                  child: Text(
                    l.settingsGoogleMapsNotice,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.aon.contentSecondary),
                  ),
                ),
              ],
            ),
            if (consent == MapsConsent.accepted) ...[
              const SizedBox(height: AonSpacing.space2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => ref.read(mapsConsentProvider.notifier).revoke(),
                  child: Text(l.settingsRevokeGoogleConsent),
                ),
              ),
            ],
          ],
        ),
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
            const SizedBox(height: AonSpacing.space3),
            Text(
              config.faculty,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.aon.contentTertiary),
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
    final theme = Theme.of(context);
    final body = theme.textTheme.bodySmall
        ?.copyWith(color: context.aon.contentSecondary);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hero image', style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(config.heroCredit, style: body),
            const SizedBox(height: AonSpacing.space4),
            Text('Event materials', style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              'Programme, map and branding © ${config.host}, '
              '${config.faculty}.',
              style: body,
            ),
            const SizedBox(height: AonSpacing.space4),
            Text('Map data', style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('© OpenStreetMap contributors.', style: body),
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.aon.contentSecondary),
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
    return const _InfoCard(
      icon: Icons.error_outline_rounded,
      title: 'Settings unavailable',
      body: 'Your preferences couldn’t be opened on this device. The app '
          'still works — it just won’t remember this choice.',
    );
  }
}
