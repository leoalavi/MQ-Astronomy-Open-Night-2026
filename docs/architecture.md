# Architecture — SUPERSEDED

**This document is superseded by [`/ARCHITECTURE.md`](../ARCHITECTURE.md) (2026-08-31).**

It was written on 2026-08-07 (initial commit `b790d82`) and was never updated as
the app grew. By the end of August it was actively misleading — most notably it
stated:

> ### No location permission

which stopped being true when the Map Parity programme landed. The app now uses
`geolocator` for a live position on the campus map, `sensors_plus` for compass
heading, and a consent-gated Google Routes call for walking directions. It also
claimed "Dark theme only"; both light and dark themes are real and the visitor
can choose (`main.dart`, `themeMode`).

The content that remains accurate — data compiled in rather than loaded, time
injected rather than read, `DataConfidence` as a first-class type — is carried
forward and expanded in the new document.

**Do not add to this file.** Update `/ARCHITECTURE.md` instead.
