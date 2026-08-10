import 'package:aon2026/models/data_confidence.dart';

/// One stop on the Astronomy Passport trail.
///
/// [code] is a low-friction event token printed on the venue sign — NOT a
/// secret and NOT proof of attendance (design §4.1). An offline, open-source
/// app that can validate a code necessarily contains enough to validate it, so
/// the codes are deliberately not treated as secrets. Staff redemption at the
/// booth is the actual control.
class StampStation {
  const StampStation({
    required this.venueId,
    required this.code,
    this.codeConfidence = DataConfidence.placeholder,
  });

  /// Foreign key into [VenuesData]; always one of the 9 `eventVenue`s.
  final String venueId;

  /// The token on the sign. Compared case-insensitively.
  final String code;

  /// `placeholder` until the organiser confirms the printed code. While any
  /// station is placeholder the domain release gate refuses collection in
  /// release builds (see PassportPolicy / passportCollectionEnabledProvider).
  final DataConfidence codeConfidence;
}
