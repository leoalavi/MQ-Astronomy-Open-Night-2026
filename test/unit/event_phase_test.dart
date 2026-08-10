import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/event_phase.dart';

void main() {
  final opens = EventInfo.startsAt; // 4pm
  final closes = EventInfo.endsAt; // 10pm

  EventPhase phaseAt(DateTime now) => EventPhaseService.phaseFor(
        now: now,
        startsAt: opens,
        endsAt: closes,
      );

  group('phaseFor', () {
    test('weeks out is future', () {
      expect(phaseAt(DateTime(2026, 8, 10, 12)), EventPhase.future);
    });

    test('earlier the same day is today', () {
      expect(phaseAt(EventInfo.at(9)), EventPhase.today);
    });

    test('within two hours of doors is startingSoon', () {
      expect(phaseAt(EventInfo.at(15)), EventPhase.startingSoon);
      expect(phaseAt(EventInfo.at(14)), EventPhase.startingSoon);
      // Exactly two hours out still counts.
      expect(phaseAt(EventInfo.at(13, 59)), EventPhase.today);
    });

    test('doors open is running', () {
      expect(phaseAt(EventInfo.at(16)), EventPhase.running);
      expect(phaseAt(EventInfo.at(19)), EventPhase.running);
    });

    test('the last 45 minutes is endingSoon', () {
      expect(phaseAt(EventInfo.at(21, 30)), EventPhase.endingSoon);
      expect(phaseAt(EventInfo.at(21, 15)), EventPhase.endingSoon);
      expect(phaseAt(EventInfo.at(21, 14)), EventPhase.running);
    });

    test('close is exclusive — 10pm sharp has ended', () {
      expect(phaseAt(EventInfo.at(22)), EventPhase.ended);
      expect(phaseAt(EventInfo.at(23)), EventPhase.ended);
    });

    test('isLive covers exactly the open window', () {
      expect(phaseAt(EventInfo.at(19)).isLive, isTrue);
      expect(phaseAt(EventInfo.at(21, 30)).isLive, isTrue);
      expect(phaseAt(EventInfo.at(15)).isLive, isFalse);
      expect(phaseAt(EventInfo.at(22)).isLive, isFalse);
    });

    test('a day after the event is ended, not future', () {
      // Guards against a naive "is it the same day" check ordering bug.
      expect(phaseAt(DateTime(2026, 9, 20, 12)), EventPhase.ended);
    });
  });

  group('event config drives the window', () {
    test('the shipped config is Astronomy Open Night', () {
      final config = EventConfig.astronomyOpenNight;
      expect(config.id, 'aon-2026');
      expect(config.name, 'Astronomy Open Night');
      expect(config.startsAt, EventInfo.startsAt);
      expect(config.endsAt, EventInfo.endsAt);
      expect(config.duration, const Duration(hours: 6));
    });

    test('terminology is night vocabulary, not Open Day vocabulary', () {
      final t = EventConfig.astronomyOpenNight.terminology;
      expect(t.myPlan, 'My Night');
      expect(t.laterLabel, 'Later tonight');
      expect(t.eventPeriod, 'tonight');
      // The Open Day words must not leak into the Astronomy config.
      expect(t.myPlan, isNot(contains('Day')));
    });

    test('defaults to dark — it is an after-dark event', () {
      expect(
        EventConfig.astronomyOpenNight.defaultThemeMode,
        AppThemeMode.dark,
      );
    });

    test('scan is off until the QR contract exists', () {
      // Feature flags hide unfinished features rather than stubbing them.
      final f = EventConfig.astronomyOpenNight.features;
      expect(f.scan, isFalse);
      expect(f.stamps, isFalse);
      expect(f.panorama, isTrue);
      expect(f.wayfinding, isTrue);
      expect(f.myPlan, isTrue);
    });

    test('the hero image carries its attribution', () {
      // A hero without a credit is a licensing problem; the type makes it
      // required, this pins the actual value.
      expect(
        EventConfig.astronomyOpenNight.heroCredit,
        'A Deep Triangulum Galaxy — Aleix Roig, 2026',
      );
    });
  });

  group('AppThemeMode', () {
    test('round-trips by name, not by enum index', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromName(mode.name), mode);
      }
    });

    test('falls back to dark for unknown or missing stored values', () {
      expect(AppThemeMode.fromName(null), AppThemeMode.dark);
      expect(AppThemeMode.fromName('sepia'), AppThemeMode.dark);
    });
  });
}
