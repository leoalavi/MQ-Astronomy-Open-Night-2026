/// Capture input, typed by source.
///
/// Scanning and manual entry have different validity rules: a bare token is
/// valid from the keypad, but a QR without the `AON2026:` namespace must be
/// rejected. The source therefore cannot be flattened to a plain `String`.
sealed class StampInput {
  const StampInput();
  const factory StampInput.scan(String rawQr) = ScanInput;
  const factory StampInput.manual(String rawCode) = ManualInput;
}

class ScanInput extends StampInput {
  const ScanInput(this.rawQr);
  final String rawQr;
}

class ManualInput extends StampInput {
  const ManualInput(this.rawCode);
  final String rawCode;
}

/// The outcome of resolving a capture against the station table.
sealed class StampResult {
  const StampResult();
}

class StampCollected extends StampResult {
  const StampCollected(this.venueId);
  final String venueId;
}

class StampAlreadyHave extends StampResult {
  const StampAlreadyHave(this.venueId);
  final String venueId;
}

class StampUnknown extends StampResult {
  const StampUnknown();
}

/// Collection is currently disabled — a release build whose station codes are
/// still placeholders (design §10). The UI shows a "not live yet" message.
class StampDisabled extends StampResult {
  const StampDisabled();
}
