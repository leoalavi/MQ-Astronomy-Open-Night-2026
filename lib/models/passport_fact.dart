import 'package:aon2026/models/data_confidence.dart';

/// One activity-linked astronomy learning moment for a passport station.
///
/// Separate from `StampStationsData`: sign codes and educational content have
/// different owners and review cycles (design §5). Facts ship as `placeholder`
/// drafts and are promoted to `confirmed`/`derived` only after astronomy-team
/// sign-off (design §6/§7); the release publication gate (design §6) decides
/// what is shown to attendees.
class PassportFact {
  const PassportFact({
    required this.venueId,
    required this.activityLabel,
    required this.title,
    required this.fact,
    this.confidence = DataConfidence.placeholder,
    this.sourceRef,
  });

  final String venueId;
  final String activityLabel;
  final String title;
  final String fact;
  final DataConfidence confidence;

  /// Stable reviewer reference (e.g. `MQ-AON-2026-LGS`); not rendered to
  /// attendees. Maps to a row in docs/passport-fact-sources.md.
  final String? sourceRef;
}
