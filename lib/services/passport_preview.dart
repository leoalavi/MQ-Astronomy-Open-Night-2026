import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets someone try the stamp rally before the codes on the venue signs exist.
///
/// Every release build ships with the nine station codes still `AON-*-TBC`, so
/// `PassportPolicy.isCollectionEnabled` refuses collection and the Passport tab
/// reduces to a single sentence. That is a *dormant feature*, which App Review
/// guideline 2.3.1(a) forbids outright — and it is also simply a worse app:
/// nobody can see what the passport is until the one night it works.
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
