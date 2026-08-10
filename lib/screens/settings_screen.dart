import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/text_scale.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/app_settings.dart';
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
    final config = ref.watch(eventConfigProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonSpacing.space16,
        ),
        children: [
          // ── Appearance ──
          const SectionHeader(
            title: 'Appearance',
            icon: Icons.dark_mode_rounded,
          ),
          const _InfoCard(
            icon: Icons.nightlight_round,
            title: 'Built for the dark',
            body:
                'This app stays in its night theme. Astronomy Open Night runs '
                'from dusk until 10pm, and a bright screen next to a telescope '
                'spoils night vision — yours and everyone else’s nearby.\n\n'
                'If you need a brighter screen, use your phone’s own '
                'brightness control.',
          ),

          // ── Motion ──
          const SectionHeader(
            title: 'Motion',
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
                title: const Text('Reduce motion'),
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
          const SectionHeader(
            title: 'Text size',
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
          const SectionHeader(
            title: 'Privacy',
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
                'The only thing it fetches from the internet is map imagery.',
          ),

          // ── Credits ──
          const SectionHeader(
            title: 'Credits',
            icon: Icons.copyright_rounded,
          ),
          _CreditsCard(config: config),
        ],
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
                  ?.copyWith(color: AonColors.contentSecondary),
            ),
            const SizedBox(height: AonSpacing.space3),
            Text(
              config.faculty,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AonColors.contentTertiary),
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
        ?.copyWith(color: AonColors.contentSecondary);

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
            Icon(icon, size: AonSpacing.iconMd, color: AonColors.amber),
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
                        ?.copyWith(color: AonColors.contentSecondary),
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
        color: AonColors.night900,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: AonColors.night700),
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
