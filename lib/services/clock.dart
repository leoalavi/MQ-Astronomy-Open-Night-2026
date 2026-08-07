import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now".
///
/// Nothing in this app may call `DateTime.now()` directly. Everything time
/// dependent — the whole "What's On Now" screen, the live/soon badges on
/// programme cards — reads the clock through this abstraction instead.
///
/// Two reasons, and the second is the one that matters:
///
/// 1. **Testability.** Assertions about "happening now" need a fixed instant,
///    otherwise the test suite passes only during a six-hour window on
///    19 September 2026 and fails forever after.
/// 2. **Demonstrability.** The event is in the future. Every stakeholder demo,
///    every organiser review, and all manual QA before the night happens on a
///    date when the honest answer to "what's on now?" is "nothing". A
///    switchable clock is how the app is reviewable at all before it ships.
abstract interface class Clock {
  DateTime now();
}

/// Real wall-clock time. Used in production.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock pinned to a fixed instant. Used by tests and the in-app time
/// simulator.
class FixedClock implements Clock {
  const FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime now() => _instant;
}

/// A clock that runs at normal speed but offset from real time, so a demo can
/// be scrubbed to 7pm on event night and then continue ticking naturally.
class OffsetClock implements Clock {
  OffsetClock(this.offset);

  final Duration offset;

  @override
  DateTime now() => DateTime.now().add(offset);
}

/// The underlying wall-clock source.
///
/// **This is the one tests override.** It sits below the time simulator on
/// purpose: overriding [clockProvider] directly would pin the clock so hard
/// that the in-app simulator stopped working, and then a widget test could
/// never exercise the simulator itself.
final baseClockProvider = Provider<Clock>((ref) => const SystemClock());

/// The clock the app reads.
///
/// Resolves in priority order: the in-app time simulator if it is engaged,
/// otherwise [baseClockProvider].
final clockProvider = Provider<Clock>((ref) {
  final override = ref.watch(simulatedTimeProvider);
  if (override != null) return FixedClock(override);
  return ref.watch(baseClockProvider);
});

/// When non-null, the app behaves as though this is the current time.
///
/// Exposed in the UI behind the "Preview event night" control on the
/// What's On Now screen. Null in normal operation.
///
/// A `NotifierProvider` rather than the `StateProvider` MQ Journey uses —
/// Riverpod 3 removed `StateProvider` entirely.
final simulatedTimeProvider =
    NotifierProvider<SimulatedTimeNotifier, DateTime?>(
  SimulatedTimeNotifier.new,
);

class SimulatedTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Pins the app clock to [instant] on the event date.
  void set(DateTime instant) => state = instant;

  /// Returns the app to real wall-clock time.
  void clear() => state = null;
}

/// Convenience: the current time as the app understands it.
///
/// This is a plain `Provider`, so it does not tick by itself — screens that
/// need live updates watch [tickingNowProvider] instead.
final nowProvider = Provider<DateTime>((ref) => ref.watch(clockProvider).now());

/// "Now", re-emitted every 30 seconds.
///
/// 30s is chosen against the shortest thing we display: the "starting soon"
/// window is 30 minutes, and sessions are 30–45 minutes, so a half-minute of
/// staleness is never visible to a user, while polling any faster would keep
/// the CPU awake and cost battery on a night when people need their phones to
/// last until 10pm.
final tickingNowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock.now();
  yield* Stream.periodic(
    const Duration(seconds: 30),
    (_) => clock.now(),
  );
});

/// **The one provider the UI should watch for "now".**
///
/// Wraps [tickingNowProvider] so screens never deal with an `AsyncValue`.
/// Before the stream's first event arrives it falls back to a synchronous
/// read, so the app never flashes a loading spinner for a value it can
/// compute instantly — an empty programme for one frame reads as a bug.
///
/// The return type is written out rather than inferred: `AsyncValue.value` is
/// nullable, and letting Dart infer `DateTime?` here would push a needless
/// null check into every call site.
final currentTimeProvider = Provider<DateTime>((ref) {
  final DateTime now =
      ref.watch(tickingNowProvider).value ?? ref.watch(clockProvider).now();
  return now;
});
