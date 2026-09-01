import 'dart:async';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';

/// Fake used across all Phase A state/wiring tests.
class FakeLocationService implements LocationService {
  FakeLocationService({this.grant = LocationStatus.granted});
  LocationStatus grant;
  final _fixes = StreamController<UserLocationFix>.broadcast();
  final _service = StreamController<bool>.broadcast();
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  /// How many times the OS permission prompt was asked for. Lets tests assert
  /// the first-Map-entry auto-prompt fires exactly once (no re-prompting on
  /// every tab visit).
  int requestCount = 0;

  void emit(UserLocationFix f) => _fixes.add(f);
  void emitError(Object e) => _fixes.addError(e);
  void emitServiceEnabled(bool v) => _service.add(v);

  @override
  Future<LocationStatus> status() async => grant;
  @override
  Future<LocationStatus> request() async {
    requestCount++;
    return grant;
  }
  @override
  Stream<UserLocationFix> watch() => _fixes.stream;
  @override
  Stream<bool> serviceEnabledChanges() => _service.stream;
  @override
  Future<void> openAppSettings() async => appSettingsOpened++;
  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}
