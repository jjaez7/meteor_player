# GLASNYL: Visual Vinyl Player

> **An Android music player that visualizes music** — a glassmorphism-styled LP player that reads your existing streaming apps and wraps them in a fully reactive visual layer.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Kotlin-Native-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white"/>
  <img src="https://img.shields.io/badge/Google%20Play-Published-414141?style=for-the-badge&logo=googleplay&logoColor=white"/>
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.glasnyl.app">
    <strong>▶ View on Google Play Store</strong>
  </a>
  &nbsp;·&nbsp;
  <a href="https://youtube.com/shorts/TT0jgLfhIPo">
    <strong>▶ Watch Demo Video</strong>
  </a>
  &nbsp;·&nbsp;
  <a href="https://github.com/jjaez7/meteor_player.git">
    <strong>▶ GitHub Repository</strong>
  </a>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Motivation](#motivation)
- [Core Technical Goals](#core-technical-goals)
- [System Architecture](#system-architecture)
- [Async & Concurrency Design](#async--concurrency-design)
- [Algorithm Design](#algorithm-design)
- [Service Design & Code Quality](#service-design--code-quality)
- [UI Screenshots](#ui-screenshots)
- [Deployment & Metrics](#deployment--metrics)
- [Technical Limitations & Future Research](#technical-limitations--future-research)
- [Roadmap](#roadmap)
- [Tech Stack](#tech-stack)

---

## Overview

| Item | Details |
|------|---------|
| **Project Name** | GLASNYL: Visual Vinyl Player |
| **Platform** | Android (Flutter + Kotlin Native) |
| **Development Period** | Dec 14, 2025 ~ Present (Solo development) |
| **Source Files** | ~43 Dart files + Kotlin Native bridge |
| **Status** | Released on Google Play Store (Mar 5, 2026) |
| **Installs** | 227 installs across 59 countries (as of May 6, 2026) |

GLASNYL is a solo-developed Android music player built with Flutter and Kotlin Native. Rather than playing music itself, it reads the playback state of any music app — Spotify, YouTube Music, Melon — via Android's MediaSession API, and overlays a fully reactive visual experience: real-time album art palette theming, millisecond-accurate lyrics synchronization, and live FFT spectrum visualization.

---

## Motivation

Streaming apps like Spotify, YouTube Music, and Melon provide great music experiences, but they share a fundamental constraint: **you cannot change the UI without changing the platform**.

The catalyst for GLASNYL came from observing "mood music" videos on YouTube — dark backgrounds with album art and lyrics overlaid — that regularly accumulate millions of views. The appeal isn't the music itself, but the unified experience of sound and visuals working together. Yet that experience was fragmented: you could have the visuals or your preferred music library, never both.

To solve this, GLASNYL needed to read playback state from external apps without being tied to any specific platform. Android's **MediaSession API** provides exactly this — a standard interface for bridging playback apps and UI layers. This meant GLASNYL could overlay a visual layer on top of whatever music app the user already uses.

Three design principles emerged from this:

1. **The album art already encodes the music's emotional language** — artists intentionally use color, composition, and typography to compress the feel of a record into a single image. (Supported empirically by Dorochowicz & Kostek, 2019, IEEE SPA.)
2. **Lyrics should synchronize at millisecond precision**, not just display statically.
3. **The audio signal itself should be rendered visually** — FFT spectrum analysis makes the invisible structure of sound visible in real time.

---

## Core Technical Goals

| Goal | Implementation |
|------|---------------|
| **Real-time MediaSession integration** | Read playback info from external apps (Spotify, YouTube Music, Melon) via Android MediaSession API and reflect it in Flutter UI in real time |
| **Synchronized lyrics rendering** | Fetch LRC-format lyrics via LRCLIB REST API, parse millisecond timestamps, and drive smooth auto-scroll via Ticker-based interpolation — no API polling |
| **Album art palette extraction** | Use `palette_generator` to extract dominant colors, convert to HSL color space, and auto-apply as the entire UI theme |
| **Responsive layout engine** | Handle portrait / landscape / PiP / foldable flip-cover across 4 display modes from a single codebase using runtime dynamic calculation |
| **Freemium monetization** | Google Play IAP (non-consumable) + AdMob rewarded ads forming a real production-grade revenue structure |
| **FFT audio spectrum visualization** | Android AudioRecord PCM → Kotlin FFT → EventChannel → Flutter CustomPainter; real-time 64-band spectrum. Auto-fallback to simulation when signal is absent |

---

## System Architecture

### Layer Architecture

The system is divided into 4 layers, with dependencies flowing strictly downward. This means swapping a Service Layer API never requires touching UI Layer code.

```
lib/
├── main.dart / player_screen.dart / onboarding_screen.dart   # Entry points & core screens
├── logic/      # Logic Layer — music_controller, player_logic
├── models/     # Data Models — lyric_model, player_config
├── services/   # Service Layer — lyrics, ad, purchase, share
├── features/   # Feature modules — pip, screen_lock, menu_actions
├── menu/       # Menus & dialogs — settings, terms, pass (9 files)
├── widgets/    # UI components — vinyl, needle, controls (14 files)
└── utils/      # Utilities — color_manager, layout_engine
```

| Layer | Files & Responsibility |
|-------|----------------------|
| **UI Layer** | `player_screen.dart`, `onboarding_screen.dart`, `concert_effects.dart` — Screen rendering, user input, animation. No business logic. |
| **Logic Layer** | `player_logic.dart`, `music_controller.dart`, `player_config.dart`, `lyric_model.dart` — Business rules, fully independent of UI |
| **Service Layer** | `lyrics_service.dart`, `ad_service.dart`, `purchase_service.dart`, `share_service.dart` — External system integrations: HTTP, IAP, AdMob |
| **Platform Layer** | Kotlin Native Bridge (MethodChannel / EventChannel), SharedPreferences, Google Play |

### Flutter ↔ Android Native IPC Design

Flutter runs on the Dart VM and cannot directly access Android OS APIs like MediaSession. GLASNYL solves this with a **dual-channel IPC architecture** similar to OS inter-process communication, where Flutter and Android communicate via message queues.

| Channel | Direction | Events / Methods | Purpose |
|---------|-----------|-----------------|---------|
| `com.glasnyl.app/media_control` | Flutter → Kotlin | `play`, `pause`, `seek`, `setVolume`, `getAlbumArt`, `getCurrentStatus` | Command delivery (synchronous) |
| `com.glasnyl.app/media_status` | Kotlin → Flutter | `{ title, artist, isPlaying, position(ms), duration(ms) }` | Real-time playback state streaming |
| `com.glasnyl.app/pip_status` | Kotlin → Flutter | `onPipModeChanged(bool)`, `onPipAction(TOGGLE/NEXT/PREV)` | PiP mode change notifications |
| `com.glasnyl.app/volume_events` | Kotlin → Flutter | `volume(double 0.0~1.0)` | System volume change real-time reflection |
| `com.glasnyl.app/fft_data` | Kotlin → Flutter | `List<double>` 32-band frequency energy array | FFT spectrum data |

`MethodChannel` maps to Dart's `Future` for single request-response patterns. `EventChannel` maps to Dart's `Stream` for continuous data streaming. The native side registers `MediaController.Callback` and pushes state changes to the EventChannel.

### State Management Strategy

Flutter's Impeller engine (which replaced Skia) requires careful management of rebuild scopes — overusing `setState()` rebuilds the entire widget tree, making 120fps difficult to sustain. GLASNYL uses three patterns contextually:

| Pattern | Applied To | Reason |
|---------|-----------|--------|
| `setState()` | Playback state, track info, colors — cases requiring full screen rebuild | Code simplicity preferred; low frequency |
| `ValueNotifier` + `ValueListenableBuilder` | `_positionNotifier` (position), `_volumeNotifier` (volume) | Updated 60x/second — `setState` would cause full rebuilds |
| `StreamController.broadcast()` | `_turntableProgressCtrl` — circular turntable progress bar | Multiple widgets need to independently subscribe to the same stream |

---

## Async & Concurrency Design

### Dart's Event Loop Model and Single-Thread Concurrency

Dart runs on a single-threaded event loop (identical in structure to JavaScript's). All async work is processed sequentially through the microtask queue and event queue. Running CPU-bound work on the main Isolate blocks the UI.

**The problem encountered:** Album art blur processing — receiving a `Uint8List`, applying `ui.ImageFilter.blur()`, then encoding to PNG — was running on the main Isolate. Every time a track changed, two things happened simultaneously:
- Flutter console logged: `"Skipped 10 frames! The application may be doing too much work on its main thread."`
- The LP record rotation animation visibly stuttered, because `AnimationController` couldn't get its per-frame callbacks while the Isolate was occupied.

**Attempted fix 1:** Using `compute()` to move blur processing to a separate Isolate — failed with `"UI actions are only allowed on main thread"`. `dart:ui`'s Canvas, ImageFilter, and PictureRecorder APIs are coupled to Flutter's rendering pipeline and simply cannot be called outside the main Isolate.

**Attempted fix 2:** Forcing the app from 120fps to 60fps — counter-intuitively made frame drops *more* frequent.

**Final solution:** Two optimization strategies combined:

```dart
// Strategy 1: 100ms delay after album art arrival, allowing first render to complete
await Future.delayed(const Duration(milliseconds: 100));

// Strategy 2: Downsample to targetWidth: 300 before blurring
// Original resolution (typically 800×800) → 300px = ~85% fewer pixels to process
final rawCodec = await ui.instantiateImageCodec(bytes, targetWidth: 300);
```

### Race Condition Prevention for Lyrics Requests

When tracks change in rapid succession, an earlier HTTP request for a previous track can arrive *after* the current track's request, overwriting the lyrics incorrectly. This was discovered through logs: a lyrics-loaded success log would appear, but the screen still showed the previous track's "no lyrics" state.

**Solution — Token (generation counter) pattern:**

```dart
int _lastRequestToken = 0;

Future<void> _updateLyrics(dynamic item) async {
  final int token = ++_lastRequestToken;

  // Deduplication: return immediately if same track
  if (_lastFetchedSongId == id && _lyrics.isNotEmpty) return;

  // 500ms debounce: suppress rapid successive calls after track change
  await Future.delayed(const Duration(milliseconds: 500));

  // If a newer request has arrived during the wait, discard this result
  if (token != _lastRequestToken) return;

  final result = await LyricsService.getLyrics(title, artist);

  // Re-check after HTTP delay — token may have changed during network wait
  if (mounted && token == _lastRequestToken) {
    setState(() { _lyrics = result.lyrics; });
  }
}
```

Since Dart HTTP Futures cannot be cancelled directly, token checking controls whether the result is actually applied.

### Ticker-Based Lyrics Scroll Synchronization

Two approaches were tried and failed before the final design:

1. **Stopwatch-based elapsed time** — Stopwatch runs independently of Flutter's widget lifecycle, so it reset on every widget rebuild, causing lyrics to jump back to the top repeatedly.
2. **`DateTime.now()` absolute time** — Wall clock time keeps advancing during pause, so lyrics position reset to 0 on resume.

**Final solution — Ticker-based software interpolation:**

```dart
// Last synchronized playback position
Duration _basePosition = Duration.zero;
// Elapsed time measured by Ticker since last sync
Duration _elapsedSinceSync = Duration.zero;

_ticker = createTicker((elapsed) {
  if (elapsed - _lastTickerCheck < _throttleInterval) return; // 25ms throttle
  _lastTickerCheck = elapsed;
  _elapsedSinceSync = elapsed;
  _checkAndScroll();
});

// Interpolated current position: basePosition + elapsed + 50ms lookahead compensation
final precisePos = _basePosition + _elapsedSinceSync + const Duration(milliseconds: 50);
```

The Ticker is bound to Flutter's rendering pipeline, so it isn't affected by widget rebuilds, and stopping it on pause avoids both previous bugs. Seek events (position jumps > 300ms) trigger a forced `basePosition` reset and Ticker restart.

**Lyrics index search optimization — O(n) → O(log n):**

The initial linear search (comparing every lyric line's timestamp against the current position, up to 200 comparisons every 25ms) caused lyrics to lag ~1 second and fail to keep up with rapid lyric changes. Replacing it with binary search (lyrics are already time-sorted) reduced worst-case comparisons from 200 to 8. Bit-shift division (`>> 1` instead of `/ 2`) provides additional micro-optimization.

### Parallel Initialization with `Future.wait`

Sequential initialization (SharedPreferences → AudioService) accumulates latency. Since these are independent operations, `Future.wait()` runs them concurrently:

```dart
// Sequential: ~110ms total
// Parallel: ~80ms total (only the slower one)
final results = await Future.wait([
  SharedPreferences.getInstance(),  // ~30ms
  AudioService.init(...),           // ~80ms
]);

// AdMob conflicts with MediaSession registration — isolated to post-runApp with 5s delay
unawaited(AdService.initAdmobWithDelay());
```

AdMob's SDK temporarily requests Android Audio Focus during initialization, which conflicts with AudioService's MediaSession registration and prevents metadata (title, artist, album art) from being fetched at startup. The solution is to run AdMob initialization as a fully detached `unawaited()` task after `runApp()`, with a 5-second internal delay.

---

## Algorithm Design

### Lyrics Search — 6-Stage Fallback Pipeline

Rather than using a black-box commercial API (Musixmatch, LyricsFind), GLASNYL uses the open-source **LRCLIB API** with a custom multi-stage fallback pipeline. This allows diagnosing failure modes and adding targeted fixes for each case.

Korean tracks in particular posed challenges: LRCLIB often only has them registered in romanized form (e.g., IU's "홀씨" stored as "Hollsi"). Initial hit rate for Korean tracks was ~3/10. After the full 6-stage pipeline, it reached ~9/10.

| Stage | Method | Problem Solved | API Endpoint |
|-------|--------|---------------|-------------|
| 1 | Exact match | General case | `/api/get?track_name=&artist_name=` |
| 2 | Strip `feat.` then retry | "에잇 (feat. BTS)" → "에잇" | `/api/get` |
| 3 | Fuzzy search (title + artist) | API naming differences | `/api/search?q=` |
| 4 | Title-only fuzzy search | Artist name mismatch | `/api/search?q=title` |
| 4.5 | Strip special characters | Tracks like "LOVE♥DIVE" | `/api/search?q=` |
| 5 | Manual romanization map | Hardcoded common Korean tracks | `/api/get` |
| 6 | Google Translate API → retry | All remaining Korean titles | `/api/get`, `/api/search` |

Input normalization uses pure functions (no side effects, easily testable):

```dart
// _cleanTitle(): Remove version tags, year suffixes, bracket content
// "에잇 (Prod. SUGA) [2023 Remaster]" → "에잇"
static String _cleanTitle(String title) { ... }

// _stripSpecialChars(): Keep only alphanumerics, Korean, spaces
// "LOVE♥DIVE" → "LOVEDIVE"
static String _stripSpecialChars(String title) { ... }
```

Each HTTP request has a 12-second timeout. `TimeoutException` and general `IOException` are handled separately, mapping to a `LyricStatus` enum (`loading / success / noLyrics / networkError / timeout`) so the UI can show distinct messages for "no lyrics found" vs "network error."

LRCLIB provides lyrics in LRC format with millisecond timestamps (e.g., `[00:16.98] So are you happy now?`), which feeds directly into the Ticker-based synchronization described above.

### Album Art Palette Extraction & HSL Color Conversion

The design principle: **artists intentionally encode a record's emotional language into album art color**. This is empirically supported by Dorochowicz & Kostek (2019, IEEE SPA), which analyzed album covers across 34 genres and 9 countries and found statistically significant genre-specific differences in color characteristics.

GLASNYL inverts this relationship: extract the artist's intended color from the album art, then let that color define the entire player UI theme.

`palette_generator` uses the Median Cut algorithm to extract dominant colors. However, directly applying extracted RGB colors to backgrounds produced garish, fluorescent results. The fix was converting to **HSL (Hue-Saturation-Lightness)** color space, which allows independently adjusting saturation and lightness while preserving the hue — something impossible to express cleanly in RGB.

```dart
// 1. Accent color: vibrant → lightVibrant → dominant (fallback chain)
Color accent = palette.vibrantColor?.color
    ?? palette.lightVibrantColor?.color
    ?? palette.dominantColor?.color
    ?? const Color(0xFF735DA5);

// 2. Background: lower saturation to 0.1, fix lightness at 0.92
//    → Pastel background that's easy on the eyes regardless of album art
HSLColor hsl = HSLColor.fromColor(accent);
Color bg = hsl.withSaturation(0.1).withLightness(0.92).toColor();

// 3. Text: lower lightness to 0.2; force Colors.black87 if luminance > 0.4
//    → Safety guard for WCAG contrast ratio compliance
Color text = hsl.withLightness(0.2).withSaturation(0.3).toColor();
if (text.computeLuminance() > 0.4) text = Colors.black87;
```

### Responsive Layout Calculation Engine (`layout_engine.dart`)

Initial fixed pixel values for LP position, size, and needle position broke on different screen aspect ratios. Testing on Galaxy S21, S23 Ultra, Tab S9, Tab S9+ (using the popup window feature to test all proportions), and a foldable flip cover emulator confirmed this.

The solution: a dedicated `layout_engine.dart` that computes LP position, size, needle position, text size, and progress bar width dynamically at runtime based on screen size, orientation, and PiP state.

```dart
// Needle position: relative offset from LP center
// xGap=0.32, yGap=0.72 — determined through repeated real-device visual testing
static Offset calculateNeedlePos(Offset lpPos, double lpSize) {
  double radius = lpSize / 2;
  return Offset(
    lpPos.dx + (radius * 0.32),  // 32% right of center
    lpPos.dy - (radius * 0.72),  // 72% above center
  );
}

// LP size: 82% of screen width, capped at 580px
// → Covers both small phones and tablets
double lpSize = size.width * 0.82;
if (lpSize > 580) lpSize = 580;

// Foldable flip cover detection: landscape but under 600px wide
final bool isFlipCover = size.width > size.height && size.width < 600;
```

### FFT Spectrum Real-Time Visualization

FFT (Fast Fourier Transform) converts a time-domain audio signal into the frequency domain, revealing how much energy exists in sub-bass, mid, and high frequency bands at any given moment.

**Data pipeline:**
```
Android AudioRecord (PCM) → Kotlin FFT → 32-band energy array → EventChannel → Flutter → 64-band expansion → CustomPainter
```

**Perceptual correction — bass emphasis:**
Human hearing perceives frequency on a logarithmic scale. A linear FFT displayed linearly makes bass frequencies nearly invisible. Per-band exponent correction compensates:

```dart
final double bandT = i / (_bandCount - 1);   // 0.0 (bass) ~ 1.0 (treble)
final double exponent = 2.2 - bandT * 1.0;   // bass: 2.2, treble: 1.2
rawV = math.pow(rawV, exponent).toDouble().clamp(0.0, 1.0);
final double gain = 0.60 + bandT * 0.28;     // treble gain correction
rawV = (rawV * gain).clamp(0.0, 0.78);
```

**Fallback simulation:** PCM capture requires the `RECORD_AUDIO` permission, which displays as "microphone recording" to users — potentially confusing for a music player. When the permission is denied, no signal arrives for 600ms+, or no external app is playing, GLASNYL automatically falls back to a software simulation that generates sub-bass, mid, and treble activity through separate mathematical formulas. On pause, all bars gradually diminish rather than cutting off abruptly.

**Three display modes (tap to cycle):**
- `AUTO` — simulated wave animation
- `FREQ` — live FFT bars (only mode that consumes real FFT signal)
- `LYRICS` — single synchronized lyric line (spectrum fades out; Ticker-based sync remains identical to main player)

**Performance:** Bars are only redrawn when the current frame differs from the previous by more than 0.001. The spectrum drawing is isolated to its own `RepaintBoundary` layer so that 64-band-per-frame updates don't affect the rendering of track info, controls, or other UI elements.

---

## Service Design & Code Quality

### Freemium Revenue Model

| Tier | Condition | Benefits | Implementation |
|------|-----------|----------|---------------|
| **Free Trial** | First hour after install | All features, unlimited | `install_time` stored in SharedPreferences; `inHours < 1` |
| **Ad Pass** | Watch 2 rewarded ads | 7 hours unlimited | AdMob `RewardedAd` × 2 → `last_ad_watch_time` stored |
| **Lifetime Pro** | $9.99 (early bird $6.99 within first hour) | Permanent unlimited | Google Play IAP non-consumable, `is_lifetime_pro` flag |

Access guard caching — the `isFullAccess()` check involves SharedPreferences I/O and is called from a 10-second polling timer. Without caching, this causes redundant I/O on every tick. Solution: 30-second cache.

### Defensive Programming Patterns

| Location | Pattern | Reason |
|----------|---------|--------|
| EventChannel listener | Separate `onError` callback + internal try-catch | Prevents the listener itself from terminating on error |
| `LyricsService` HTTP | `TimeoutException` and general `Exception` handled separately | Distinct user-facing messages for "timeout" vs "network error" |
| `AdService` | `_isAdLoading` flag + 10s timeout dialog | Prevents duplicate ad load requests |
| `PurchaseService` | `forceResetBuying()` + silent cancellation code handling | Prevents `isBuying` permanently stuck at `true` if stream never arrives |
| Native `invokeMethod` | All calls wrapped in try-catch with `debugPrint` | Prevents device-specific native bridge errors from crashing the app |
| `mounted` check | `if (!mounted) return` before any post-async `setState()` | Prevents setState on disposed widgets |

### Music App Detection Algorithm (`isMusicApp`)

`NotificationListenerService` receives all device notifications. Non-music apps with a `title` field would incorrectly appear in GLASNYL. A 3-stage filter prevents false positives:

```dart
// Stage 1: Known music app whitelist — O(1) Set lookup
final knownMusicPkgs = {
  'com.google.android.apps.youtube.music',
  'com.spotify.music',
  'com.melon.android',
  // ...
};
if (knownMusicPkgs.contains(p)) return true;

// Stage 2: Keyword matching — "media" and "stream" deliberately excluded
// (com.android.mediastorage, com.samsung.android.provider.streaming caused false positives)
final musicKeywords = ['music', 'player', 'audio', 'radio', 'vinyl', 'mp3', ...];

// Stage 3: System app blacklist checked BEFORE keyword matching
if (exclusionList.any((e) => p.contains(e))) return false;
return musicKeywords.any((kw) => p.contains(kw));
```

---

## UI Screenshots

| Screen | Description |
|--------|-------------|
| **Main Player** | Album art palette → HSL → auto-applied UI theme. LP disk rotates during playback. Needle arcs across the record tracking playback progress. Glassmorphism: blurred album art + translucent overlay. |
| **Lyrics Sync** | LRC-format lyrics from LRCLIB, parsed to ms. Ticker interpolation drives smooth scroll. Current line highlighted. Binary search finds current index every 25ms in O(log n). |
| **Onboarding** | 6-page first-run flow guiding the user to grant NotificationListener permission, with visual explanation of why it's needed. |
| **Landscape Mode** | `layout_engine.dart` dynamic calculation. LP and lyrics split left/right. All elements auto-scale to screen ratio. |
| **PiP Mode** | Small overlay window maintains playback state when app is backgrounded. Prev/next/play-pause work in PiP. Synced to Kotlin native in real time via EventChannel. |
| **Foldable Flip Cover** | Landscape but < 600px → detected as flip cover, separate layout applied. Validated on emulator. |
| **Concert Effects** | Laser beams, crowd lighting, strobe, particle bursts implemented with `AnimationController`. `RepaintBoundary` isolates effect layer from main UI rendering. |
| **Settings Dialogs** | 7 modular setting dialogs in `menu/` folder. Freemium tier status, ad pass, Lifetime Pro purchase/restore all handled here. |

---

## Deployment & Metrics

### Google Play Deployment Process

| Item | Details |
|------|---------|
| **Package Name** | `com.glasnyl.app` |
| **Release Path** | Internal Testing → Closed Testing → Open Testing → Production (Mar 5, 2026) → Privacy policy redeployment → Re-release (Apr 1, 2026) |
| **Target SDK** | compileSdk 34 (Android 14), minSdk 24 (Android 7.0+), ~96% device coverage |
| **Permissions** | `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`, `BIND_NOTIFICATION_LISTENER_SERVICE`, `RECORD_AUDIO` — no unnecessary permissions requested |
| **App Signing** | Google Play App Signing applied. Upload key (developer-held) and distribution key (Google-managed) separated |
| **IAP Products** | `glasnyl_lifetime_pro` ($9.99), `glasnyl_lifetime_pro_discount` ($6.99 early bird) — both non-consumable |

### Key Performance Indicators (as of May 6, 2026)

| Metric | Value |
|--------|-------|
| Total Installs | 227 |
| Active Devices | 47 (28-day moving average: 36.1) |
| MAU | 67 (28-day moving average: 52.4) |
| DAU | 28-day moving average: 3.29 |
| User Base Growth Rate | 28-day moving average: 99.2% |
| Store Conversion Rate | 28-day moving average: 13.2% (Google Play average: 2~5%) |
| New User Acquisition | 247 total (28-day avg: 4.21/day) |
| Active Device Growth | ~10x since launch (4.3 → 44.0 devices) |
| Countries | 44 |

All growth is **100% organic** — no paid advertising or marketing was used. The 13.2% store conversion rate is significantly above the Google Play average of 2–5%, indicating that screenshots and app description effectively communicate the value proposition to visitors.

### Deployment Problem: Google Play Privacy Policy Issue

During IAP product registration, an unexpected policy problem arose: Google Play requires seller accounts generating revenue to publicly display their legal address (as registered on the payment profile) on the store page per consumer protection law. Contacting both Google Play support and Play Console support confirmed that seller accounts cannot be downgraded to regular accounts, and removing IAP products does not remove the seller payment profile.

**Resolution:** Registered a new Google Play developer account under the same name, transferred the app, resubmitted for review, and received approval. This process provided direct hands-on understanding of Google Play seller account policy, consumer protection law requirements, and account structure constraints.

### Crash Fix: Permission Grant Timing Bug

Shortly after launch, users reported crashes when returning to the app after granting the NotificationListener permission. The cause was a timing gap: when the user returned from the permission settings screen, the app was already running but the Android service connected to that permission had not yet finished initializing. The app attempted to access the service during this window and crashed.

**Fix:** Detect the moment the app returns to the foreground, verify the service is ready before transitioning to the main screen, and hold at the permission guide screen if it isn't. After the fix, permission-related crash reports stopped entirely.

---

## Technical Limitations & Future Research

The most persistent obstacles during development shared a common structure: no matter how precisely something was engineered at the application level, without understanding the layer beneath, some problems simply couldn't be solved. These became the research questions most worth pursuing.

### Real-Time Media Synchronization

The Ticker-based lyrics sync achieves ±50ms accuracy but has a structural ceiling: the Ticker is bound to Flutter's rendering pipeline, so lyrics advance on *frame draw time*, not *audio output time*. Under high rendering load, frames are delayed — and lyrics timing delays with them. The 50ms is an average; worst-case errors are larger.

Android's `AudioTrack.getTimestamp()` provides hardware-level timestamps based on the actual audio output buffer — independent of the rendering cycle. Properly using this interface requires understanding how the OS schedules audio streams and what latency exists between the hardware buffer and the software layer.

### Perceptually Uniform Color Space

The current HSL-based palette approach has two structural limits: (1) near-achromatic album art loses the H value's meaning entirely, making the UI feel flat; (2) the fixed saturation formula (S → 0.1) is simultaneously too strong for some album art and too weak for others.

The root cause: HSL does not correspond linearly to human color perception. Yellow (H≈60°) and blue (H≈240°) can share identical HSL saturation values while appearing dramatically different in brightness and intensity to the human eye. Perceptually uniform color spaces like **CIELAB** or **OKLCH** are designed so that equal numerical differences produce equal perceived differences — enabling consistent, predictable saturation and lightness manipulation regardless of hue.

### Audio Signal Analysis Accuracy

Two theoretical gaps were identified but not resolved before deployment:

1. **Linear frequency axis:** The current 32-band linear division is corrected empirically (via per-band exponents) rather than through a mathematically grounded model like the **Mel scale**, which models how human hearing becomes less sensitive to pitch differences as frequency increases. A proper **Mel filterbank** implementation would make the spectrum accurately reflect how the music actually sounds.

2. **Spectral leakage:** FFT is currently applied directly to raw PCM blocks without a window function. Discontinuities at block boundaries introduce phantom frequency components. Applying a **Hann or Hamming window** before FFT would suppress these artifacts — the theory was understood during development, but integrating the transform into the PCM processing pipeline remained unimplemented.

Both are foundational topics in digital signal processing (STFT, Mel filterbanks, windowing theory). The long-term goal is extending the spectrum visualization to a real-time **Mel spectrogram** — a 2D view showing both time and frequency axes simultaneously.

---

## Roadmap

- **Backend server + account system** — sync settings and user-created layouts across multiple devices; community layout sharing
- **iOS port** — Flutter logic code is already platform-independent; only the Kotlin `MethodChannel` bridge needs reimplementation in Swift using `MPMediaPlayer` and `AVFoundation`
- **Custom layout system** — drag-to-position UI elements, letting users build their own player screen layouts
- **Perceptually uniform color engine** — replace HSL with OKLCH/CIELAB for consistent, perception-grounded palette generation
- **Mel filterbank FFT** — mathematically correct frequency axis aligned with human auditory perception, plus windowing to eliminate spectral leakage
- **Hardware-level audio timestamps** — use `AudioTrack.getTimestamp()` to decouple lyrics sync from the rendering cycle

---

## Tech Stack

| Category | Technologies |
|----------|-------------|
| **UI Framework** | Flutter 3.x, Dart |
| **Native Layer** | Kotlin, Android SDK, MethodChannel, EventChannel |
| **Audio** | Android MediaSession API, NotificationListenerService, AudioRecord (PCM), FFT |
| **Networking** | LRCLIB REST API, Google Translate API, `http` package (12s timeout, typed error handling) |
| **Monetization** | Google Play IAP (`in_app_purchase`), AdMob Rewarded Ads (`google_mobile_ads`) |
| **State Management** | `setState()`, `ValueNotifier`, `StreamController.broadcast()` |
| **Graphics** | `palette_generator` (Median Cut), HSL color space, Flutter CustomPainter, AnimationController |
| **Platform** | Android 7.0+ (minSdk 24), compileSdk 34 (Android 14), ~96% device coverage |
| **Distribution** | Google Play Store (Internal → Closed → Open → Production) |

---

<p align="center">
  Built solo · June 2026 – Present<br/>
  <a href="https://play.google.com/store/apps/details?id=com.glasnyl.app">Google Play</a> ·
  <a href="https://youtube.com/shorts/TT0jgLfhIPo">Demo</a> ·
  <a href="https://github.com/jjaez7/meteor_player.git">GitHub</a>
</p>