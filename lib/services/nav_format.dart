import 'package:aon2026/l10n/generated/app_localizations.dart';

/// Distance format contract (#23): `<1000 m → "412 m"`, `≥1000 → "1.4 km"`
/// (one decimal). Formatted in Dart; the ARB carries only the unit words.
String formatNavDistance(AonL10n l, int meters) {
  if (meters < 1000) return l.mapNavDistanceMeters(meters);
  return l.mapNavDistanceKm((meters / 1000).toStringAsFixed(1));
}

/// ETA format contract (#23): `<60 → "6 min"`, `≥60 → "1 hr 4 min"`. Minutes
/// are `round(seconds/60)`; the hour/minute split is computed here.
String formatNavEta(AonL10n l, Duration eta) {
  final mins = (eta.inSeconds / 60).round();
  if (mins < 60) return l.mapNavEtaMin(mins);
  return l.mapNavEtaHourMin(mins ~/ 60, mins % 60);
}
