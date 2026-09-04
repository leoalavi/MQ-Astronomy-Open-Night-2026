import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets someone try the stamp rally without standing in front of a venue sign.
///
/// This existed because every release build once shipped with the nine station
/// codes still `AON-*-TBC`: `PassportPolicy.isCollectionEnabled` refused
/// collection and the Passport tab reduced to a single sentence. That is a
/// *dormant feature*, which App Review guideline 2.3.1(a) forbids outright.
///
/// The real codes have since landed, so the domain gate now opens on its own
/// and this is no longer what makes the rally reachable. It stays because it
/// is still the only way to see what the passport does away from campus, and
/// because it can only ever *open* the gate — never close one already open.
///
/// So this mirrors [PreviewLocationService] deliberately, for the same stated
/// reason: a first-class, user-visible control in Settings rather than a hidden
/// review switch. A reviewer reaches it the same way a visitor does.
///
/// Session-only — it resets to off on every launch, so it can never quietly
/// leave a returning visitor collecting preview stamps on the night itself.
class PassportPreviewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool enabled) {
    if (state != enabled) state = enabled;
  }
}

final passportPreviewProvider =
    NotifierProvider<PassportPreviewNotifier, bool>(
  PassportPreviewNotifier.new,
);
