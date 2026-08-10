/// One-capture debounce for the QR scanner (design §7.1).
///
/// [accept] returns `true` exactly once, then `false` until [reset]. Pure — no
/// Flutter, unit-testable — so the "one decode per capture" rule is verified
/// without a camera.
class ScanGate {
  bool _open = true;

  bool accept() {
    if (!_open) return false;
    _open = false;
    return true;
  }

  void reset() => _open = true;
}
