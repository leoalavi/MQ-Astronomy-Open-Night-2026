import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/widgets/map_config.dart';

/// A simulated on-campus position, for people using the app before they arrive.
///
/// Spec §3c / D7. Deliberately a first-class, user-visible feature rather than a
/// hidden review switch: guideline 2.3.1(a) forbids hidden or dormant
/// functionality, and this is genuinely useful to an attendee planning a
/// one-night event from home.
class PreviewLocationService implements LocationService {
  const PreviewLocationService();

  @override
  Future<LocationStatus> status() async => LocationStatus.granted;

  @override
  Future<LocationStatus> request() async => LocationStatus.granted;

  /// One fix at the campus centre. The stream then closes; `LocationController`
  /// has no `onDone` handler, so a closed stream simply means "no further
  /// updates" — which is exactly true of a fixed simulated point.
  @override
  Stream<UserLocationFix> watch() => Stream<UserLocationFix>.value(
        UserLocationFix(
          position: MapConfig.campusCentre,
          accuracyMeters: 8,
        ),
      );

  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

/// Session-only: resets to off every launch, so it can never silently mislead a
/// returning visitor into reading a simulated dot as their real position.
///
/// Riverpod 3 legacy APIs are not used in this repo, so this is a `Notifier`
/// with a method rather than a `StateProvider`.
class PreviewLocationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool enabled) {
    if (state != enabled) state = enabled;
  }
}

final previewLocationProvider =
    NotifierProvider<PreviewLocationNotifier, bool>(PreviewLocationNotifier.new);
