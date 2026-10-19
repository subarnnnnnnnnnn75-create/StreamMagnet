# Known Limitations and Platform Specifics ⚠️

This document outlines platform constraints, architectural trade-offs, and behavioral nuances documented according to Working Rule #0.

---

## 1. Swarm-Dependent Startup & Speed
- **Swarm Health**: Sequential streaming performance directly correlates with the number of high-bandwidth seeders.
- **Cold Start Time**: On a healthy swarm (10+ seeds, >5 Mbps bandwidth), time-to-first-frame is typically under 10 seconds. On sparse swarms (<2 seeds), piece arrival may be delayed.
- **Dead Torrent Handling**: If metadata cannot be resolved or piece arrival halts within 60 seconds, the app triggers a `DeadTorrentFailure` with an actionable error dialog instead of hanging indefinitely.

---

## 2. iOS Platform & App Store Limitations
- **Background Execution**: iOS strictly restricts continuous background networking unless an active `AVAudioSession` with category `.playback` is active. StreamMagnet configures `UIBackgroundModes: audio` for background listening; when the app is backgrounded without audio, the torrent engine is automatically paused to prevent system kill and excessive battery drain.
- **Local Loopback Streaming**: iOS requires explicit ATS (`NSAppTransportSecurity`) exceptions for localhost binding (`NSAllowsLocalNetworking: true`), which is configured in `ios/Runner/Info.plist`.
- **App Store Review Guidelines**: Pure BitTorrent clients frequently face scrutiny under App Store Guidelines Section 2.5.2 and 5.2. StreamMagnet ensures strict compliance by:
  - Shipping with zero embedded trackers, indexers, or search directories.
  - Enforcing a first-run mandatory Legal Responsibility Notice and Terms acceptance.
  - Relying exclusively on user-supplied magnets and files.

---

## 3. Codec & Hardware Decoding Constraints
- **Hardware Acceleration**: Powered by `media_kit` (libmpv). Formats supported include MP4, MKV, WebM, AVI, MOV with H.264, H.265 (HEVC), VP9, and AV1.
- **Older Hardware**: High-bitrate 4K 10-bit HEVC or AV1 streams on budget or older chipsets (pre-2020) will fall back to software decoding and may experience frame drops or elevated thermal throttling.

---

## 4. Local Database Engine (Isar vs. SQLite)
- **Dependency Incompatibility**: The upstream `isar_generator` package is locked to legacy `source_gen ^1.2.2`, whereas `riverpod_generator 4.x` on modern Dart 3 requires `source_gen >=3.0.0 <5.0.0`.
- **Compliant Alternative**: As mandated by Working Rule #0, StreamMagnet utilizes a high-performance SQLite engine (`sqflite`) for all History, Favorites, Settings, and Resume positions, preserving clean asynchronous DAOs and complete cross-platform reliability.
