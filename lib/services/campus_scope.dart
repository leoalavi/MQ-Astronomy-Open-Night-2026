import 'dart:math' as math;

/// Whether a geographic point is inside the Astronomy Open Night campus area.
///
/// ## Why this exists
///
/// In-app walking directions are for getting between AON locations ON the
/// Macquarie University campus — not for routing a visitor in from an arbitrary
/// Sydney address. Without a scope gate, a live-GPS origin in the CBD would
/// silently generate a multi-kilometre walk, and the Routes API would happily
/// bill it. This module is the single boundary check that both the origin
/// (live GPS) and the destination (a resolved place) are validated against.
///
/// ## Where the boundary comes from
///
/// The rectangle below MIRRORS the georeferencing rectangle that pins the
/// official AON basemap artwork to GPS — `CampusProjection`'s frozen
/// `_minLat/_maxLat/_minLng/_maxLng` calibration domain. It is NOT invented:
/// it is the same extent the campus map is drawn against. `campus_scope_test`
/// pins these values against `CampusProjection.canProject` so the two can never
/// silently drift.
///
/// ## Why it is padded
///
/// That calibration rectangle is the *paper crop* — sized to the printed map,
/// not to where a person can physically stand. A visitor at the northern edge
/// of campus, or in a perimeter car park (West 5, South 2) or at the Metro
/// station, can legitimately be a few tens of metres outside the crop while
/// unambiguously "on campus". Destinations are curated points that sit inside
/// the crop by construction; origins are wherever GPS puts a real human. So the
/// scope box is the crop expanded by [kCampusScopePadMeters] — generous enough
/// to include the campus edge and its immediate car parks, far tighter than the
/// ~10 km to the CBD, so "arbitrary Sydney location" is still firmly rejected.
class CampusScope {
  const CampusScope();

  // ── Official AON basemap georeference rectangle ───────────────────────────
  // Mirrors CampusProjection's calibration domain (its `_minLat` … `_maxLng`).
  // Do not hand-tune to "make a point fit" — that is what the pad is for.
  static const double baseMinLat = -33.7772506, baseMaxLat = -33.7703261;
  static const double baseMinLng = 151.1080508, baseMaxLng = 151.1211352;

  /// The one tunable knob: how far past the printed campus crop still counts as
  /// "on campus", in metres. 500 m covers an edge-standing visitor and the
  /// perimeter car parks/Metro without admitting neighbouring suburbs (the CBD
  /// is ~10 km away — twenty times this margin).
  static const double kCampusScopePadMeters = 500;

  // Metres → degrees at this latitude. 1° lat ≈ 111_320 m everywhere; 1° lng
  // shrinks by cos(latitude). Using the campus mid-latitude is exact enough for
  // a half-kilometre tolerance band.
  static const double _midLat = (baseMinLat + baseMaxLat) / 2;
  static double get _padLat => kCampusScopePadMeters / 111320.0;
  static double get _padLng =>
      kCampusScopePadMeters / (111320.0 * math.cos(_midLat * math.pi / 180.0));

  /// True when ([lat], [lng]) falls within the padded campus rectangle. Returns
  /// false for non-finite input rather than throwing — a bad GPS fix is "not on
  /// campus", not a crash.
  bool contains(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    final padLat = _padLat, padLng = _padLng;
    return lat >= baseMinLat - padLat &&
        lat <= baseMaxLat + padLat &&
        lng >= baseMinLng - padLng &&
        lng <= baseMaxLng + padLng;
  }
}
