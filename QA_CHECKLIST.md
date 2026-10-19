# StreamMagnet Manual QA Checklist 📋

Use this checklist to perform end-to-end regression testing and manual QA validation on physical devices and emulators.

---

### Test Suite 1: Magnet & .torrent Ingestion
- [ ] **1.1 Hex Magnet Link**: Paste a standard 40-char hex magnet URI (`magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c`).
  - *Expected*: Metadata resolves within seconds and displays `TorrentDetailsSheet`.
- [ ] **1.2 Base32 Magnet Link**: Paste a 32-character base32 magnet link.
  - *Expected*: Hash is normalized to lowercase hex and metadata resolves accurately.
- [ ] **1.3 Clipboard Auto-Detection**: Copy a magnet link to system clipboard and launch or resume the app.
  - *Expected*: Floating banner appears: "Magnet detected in clipboard [Stream]".
- [ ] **1.4 File Picker Ingestion**: Tap "Open File" and pick a local `.torrent` file.
  - *Expected*: Bencode parser unpacks file list, name, and total bytes correctly.
- [ ] **1.5 System "Open With" Intent**: Open a `.torrent` file or `magnet:` link from external file manager or web browser.
  - *Expected*: StreamMagnet launches, captures the intent, and displays the torrent details sheet.

---

### Test Suite 2: Sequential Streaming & Piece Priorities
- [ ] **2.1 Header Prioritization**: Inspect console logs on stream start.
  - *Expected*: First 4 pieces and last 4 pieces are assigned `PiecePriority.urgent` / `high` with tight deadlines.
- [ ] **2.2 Initial Buffering**: Observe buffer indicator before playback.
  - *Expected*: Buffering indicator displays live download speed and peer count until 8 MB threshold is met.
- [ ] **2.3 Instant Playback**:
  - *Expected*: First video frame plays smoothly within 10 seconds on healthy swarm without waiting for the full file to download.

---

### Test Suite 3: Seeking & Adaptive Buffering
- [ ] **3.1 Playhead Seeking**: Drag scrubber or double-tap +/-10s to jump forward by 10 minutes.
  - *Expected*: Urgent piece window shifts immediately to new playhead byte offset; deadlines are reallocated; playback resumes seamlessly.
- [ ] **3.2 Extreme Seek**: Seek to the very end of the file (last 30 seconds).
  - *Expected*: Tail pieces are read from cache or downloaded without buffer underrun.
- [ ] **3.3 Adaptive Buffering on Stutter**: Throttled network speed.
  - *Expected*: When buffer drops below threshold, playback pauses, buffering indicator displays live speed, and auto-resumes once restored (no stutter loop).

---

### Test Suite 4: Media Player UX & Controls
- [ ] **4.1 Gestures**:
  - *Left swipe*: Brightness adjustment.
  - *Right swipe*: Volume adjustment.
  - *Long-press*: 2x playback speed boost; restores on release.
- [ ] **4.2 Controls Auto-Hide**: Wait 4 seconds without touching screen.
  - *Expected*: Controls fade out smoothly; single tap restores them.
- [ ] **4.3 Stats for Geeks Overlay**: Tap the analytics icon on the top bar.
  - *Expected*: Telemetry HUD displays download speed, upload speed, seeds, peers, and buffer-ahead MB.
- [ ] **4.4 Orientation & Fullscreen**: Rotate device to landscape.
  - *Expected*: Enters edge-to-edge immersive sticky fullscreen with responsive layout.

---

### Test Suite 5: In-App Browser & Content Blocker
- [ ] **5.1 Ad/Tracker Blocking**: Visit an ad-heavy test site (e.g. `caniuse.com`, `speedtest.net`).
  - *Expected*: Banner ads and tracking scripts are blocked; shield badge increments count.
- [ ] **5.2 Popup Prevention**: Click links configured to force new popup windows.
  - *Expected*: Popups and unauthorized windows are prevented from opening.
- [ ] **5.3 Magnet Sniffer**: Browse to a webpage containing public-domain legal torrent magnet links.
  - *Expected*: Bottom banner triggers: "Video Magnet Detected! [Stream Now]".
- [ ] **5.4 Multi-Tab Management**: Open up to 5 tabs, switch tabs, close individual tabs.
  - *Expected*: Tab state, scroll position, and blocked count persist cleanly.

---

### Test Suite 6: Cache & Network Settings
- [ ] **6.1 LRU Eviction**: Set cache cap to 1 GB in settings and stream a 2 GB video.
  - *Expected*: Pieces behind the playhead are evicted once cap is reached; headers remain intact.
- [ ] **6.2 Clear Cache**: Navigate to Settings -> Clear Temporary Cache.
  - *Expected*: Temporary directory is cleared and freed bytes are reported.
- [ ] **6.3 Wi-Fi Only Guard**: Enable "Wi-Fi Only" in settings and disconnect from Wi-Fi.
  - *Expected*: Warning dialog prevents cellular streaming without explicit user confirmation.
- [ ] **6.4 Foreground Service (Android)**: Start streaming and background the app.
  - *Expected*: Persistent playback notification remains visible with live speed and seed count.
- [ ] **6.5 Dead Torrent Error**: Input a magnet link with an invalid or dead hash and zero peers.
  - *Expected*: 60-second timeout triggers friendly `DeadTorrentFailure` error message.
