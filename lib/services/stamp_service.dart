import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';

/// Pure capture resolution — no I/O, no camera, fully unit-testable.
abstract final class StampService {
  static const String _qrNamespace = 'AON2026:';

  static StampResult resolve(StampInput input, Set<String> collected) {
    final token = switch (input) {
      ScanInput(:final rawQr) => _tokenFromQr(rawQr),
      ManualInput(:final rawCode) => _normalize(rawCode),
    };
    if (token == null) return const StampUnknown();
    for (final s in StampStationsData.all) {
      if (_normalize(s.code) == token) {
        return collected.contains(s.venueId)
            ? StampAlreadyHave(s.venueId)
            : StampCollected(s.venueId);
      }
    }
    return const StampUnknown();
  }

  /// A QR must carry the AON2026 namespace; anything else is a foreign code.
  static String? _tokenFromQr(String rawQr) {
    final t = rawQr.trim();
    if (!t.toUpperCase().startsWith(_qrNamespace)) return null;
    return _normalize(t.substring(_qrNamespace.length));
  }

  static String _normalize(String raw) => raw.trim().toUpperCase();
}

/// Trail rules: completion by intersection, and the placeholder release gate.
abstract final class PassportPolicy {
  static Set<String> get stationVenueIds => StampStationsData.stationVenueIds;

  static int get stationCount => StampStationsData.count;

  static int completedCount(Set<String> collected) =>
      collected.intersection(stationVenueIds).length;

  static bool isComplete(Set<String> collected) =>
      completedCount(collected) >= stationCount;

  /// Release builds refuse collection while any code is unconfirmed; debug
  /// builds always allow it (pre-event QA with placeholder/demo codes).
  static bool isCollectionEnabled(
    List<StampStation> stations, {
    required bool isRelease,
  }) {
    if (!isRelease) return true;
    return stations.every((s) => s.codeConfidence.isReliable);
  }
}
