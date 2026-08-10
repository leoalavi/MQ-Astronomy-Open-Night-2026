import 'package:flutter/widgets.dart';

/// The app-wide text-scale ceiling (Phase 5 — Gauntlet).
///
/// Every surface is verified overflow-free at this scale (see
/// `docs/superpowers/specs/2026-08-10-aon-gauntlet-textscale-phase5-design.md`).
/// The cap is held here deliberately, so the OS cannot request a scale the app
/// has not been hardened and regression-tested against. Raising it past 2.0 is
/// future accessibility work, not a value judgement about large text.
const double kMaxTextScale = 2.0;

/// Resolves an OS-requested [TextScaler] into the app's supported range
/// `[1.0, kMaxTextScale]`. This is the single source of truth for the policy;
/// `AonApp`'s `MaterialApp.builder` calls it.
TextScaler resolveAppTextScaler(TextScaler os) => os.clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: kMaxTextScale,
    );
