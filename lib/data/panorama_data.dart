import 'package:flutter/foundation.dart';

@immutable
class PanoramaTour {
  const PanoramaTour({
    required this.venueId,
    required this.manifestAsset,
    required this.placeholder,
  });
  final String venueId;
  final String manifestAsset; // e.g. 'assets/data/indoor/macquarie-theatre.json'
  final bool placeholder;
}

/// The venue->tour map. SP1 ships exactly one flagged placeholder tour.
abstract final class PanoramaData {
  static const List<PanoramaTour> tours = [
    PanoramaTour(
      venueId: 'macquarie-theatre',
      manifestAsset: 'assets/data/indoor/macquarie-theatre.json',
      placeholder: true,
    ),
  ];

  /// Exact lookup — the ONLY way a venueId becomes an asset path.
  static PanoramaTour? tourFor(String venueId) {
    for (final t in tours) {
      if (t.venueId == venueId) return t;
    }
    return null;
  }

  static bool hasTour(String venueId) => tourFor(venueId) != null;
}
