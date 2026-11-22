# Contributing to Kemudi

Bug reports, fixes and improvements are welcome. Kemudi runs on a phone in a moving car, so
two things matter more than usual: it has to stay smooth on mid-range hardware, and every
change to the UI or playback has to be tried on a real phone before it is merged.

## Getting started

You need Flutter 3.35 (CI pins 3.35.2), the Android SDK and an Android phone with USB
debugging.

```sh
flutter pub get
flutter run                 # debug build on the connected phone
flutter test                # unit and widget tests, no network needed
flutter analyze
```

Optional Mapbox routing: put `{"MAPBOX_TOKEN": "pk..."}` in `mapbox.local.json` (gitignored,
never commit it) and pass `--dart-define-from-file=mapbox.local.json`. Without it the app
routes with OSRM.

The app's text is Indonesian; keep new UI strings in Indonesian, short enough to read at a
glance. Comments explain why the code has its shape (a constraint, a platform quirk, a
measured cost), not what it does.

## Pull requests

- Say which phone and Android version you tried the change on, and what you checked.
- For anything that touches scrolling, menus, the map or playback, compare frame costs before
  and after (see Measuring below). The reference phone is a Galaxy A6+ (Snapdragon 450 class,
  Adreno 506, Android 10, 32-bit); a frame budget of 16.7 ms there is the bar.
- `flutter analyze` and `flutter test` must pass; CI runs both on every push and pull request.

## Debug builds

| Flag | Effect |
|---|---|
| `--dart-define=FRAME_LOG=true` | frame costs, UI stalls and timing marks in logcat (tag `flutter`) |
| `--profile --dart-define=BUILD_PROFILE=true` | also widget builds and layouts of 3 ms or more |
| `--dart-define=SIMULATE_DRIVE=true` | drives every started route at 40 km/h |
| `--dart-define=SIMULATE_DETOUR_S=<n>` | with SIMULATE_DRIVE, leaves the route once after n seconds |

All of them are compiled out of normal builds. Uncaught errors and the playback failures the
driver saw are kept on the phone:
`adb pull /sdcard/Android/data/io.github.rulyoctareza.kemudi/files/errors.log` (rotated to
`errors.old.log` past 256 KB).

## How it works

```
lib/
  main.dart                      AudioService + AudioSession init, error log, app root
  controllers/
    playback_controller.dart     the single owner of playback
    feed_controller.dart         trending, search, paging, errors, auto-retry
    location_controller.dart     GPS permission, position stream, background tracking
    navigation_controller.dart   destination, routes, guidance, reroute, voice cues
    drive_simulator.dart         dev-only simulated drive (SIMULATE_DRIVE)
  models/                        CarVideo, navigation models (Place, NavRoute, ...)
  services/
    youtube_service.dart         search + stream resolution (youtube_explode_dart)
    youtube_worker.dart          runs youtube_service in a background isolate
    stream_selection.dart        HLS variant choice + one-variant master playlist
    car_audio_handler.dart       media-session bridge, owns the Audio Only player
    settings_store.dart          quality, autoplay, last video + position
    geocoding_service.dart       Photon search + reverse, nearby first
    routing_service.dart         Mapbox Directions / OSRM, fallback, rate limits
    route_instructions.dart      Indonesian maneuver text for OSRM routes
    polyline.dart, geo.dart      polyline6 decoding, distances and projection
    recent_destinations.dart     recents, route provider, avoid-tolls choice
    voice_guidance.dart          flutter_tts with Indonesian voice and ducking
    video_source.dart            VideoSource interface for the feed
    platform_bridge.dart         PiP and minimize channel (see MainActivity.kt)
  screens/                       shell (headunit_screen) and the four sections
  widgets/                       rail, map, now-playing, player, grid, seek bar
  widgets/navigation/            search panel, route preview, banner, guidance bar
  theme/car_theme.dart           design tokens and shared components
  utils/                         formatting, SponsorBlock tracker, auto-retry, error log, frame log
```

**YouTube off the UI thread.** youtube_explode_dart decodes YouTube's large JSON responses
synchronously; on the A6+ that froze the UI for ~0.5 s at the first search, ~0.85 s per video
start and ~0.17 s per grid page. `YouTubeWorker` runs `YouTubeService` in a background
isolate and the app only receives plain results. The worker also downloads the media
session's artwork, so no TLS handshake runs on the UI isolate when a video changes.

**Playback.** `PlaybackController` owns the queue, the current video, the active player
(video_player for video, just_audio for Audio Only, never both at once), SponsorBlock,
autoplay, quality, recovery and resume state. Every menu, Fullscreen, PiP and the media
session go through it, so SponsorBlock and autoplay behave the same everywhere. A playback
error or a lost connection retries by itself from the same position (2, 4, 8, 15, 30, 30,
30 s, and at once when DNS answers again) before the driver sees "Ulangi".

**Media session.** `AudioService.init` registers `CarAudioHandler`; `MainActivity` extends
`AudioServiceActivity` so the session survives the activity. Steering-wheel and Bluetooth
buttons, the notification and the lock screen send play, pause, next, previous, seek and stop
to the controller. The service stays in the foreground while paused so a steering-wheel
"play" can resume from the background (Android 12+ forbids restarting it there). Video keeps
playing with the screen off (`allowBackgroundPlayback`).

**Streams** (youtube_explode_dart 2.5.3):

| Quality | Source | What plays |
|---|---|---|
| 360p | `android` client manifest without the watch page (0.2-0.3 s on the A6+) | itag 18, the only muxed progressive stream |
| 480p / 720p | `ios` player response `hlsManifestUrl`, looked up beside the 360p lookup | HLS: the variants are video-only, so the app builds a one-variant master (H.264 variant + its audio rendition) and hands it to ExoPlayer as a `data:` URI. Only some videos have an ios HLS master |
| Audio Only | `android` client manifest | best audio-only stream (opus/aac) |
| Live | `android` player response `hlsManifestUrl` | HLS, not seekable |

The HLS masters are read from the player response directly through `VideoController`, an
internal youtube_explode_dart class, because `getManifest` HEAD-checks the first adaptive
stream, which YouTube often answers with 403 for the ios client, and then retries for about
15 s. Recheck this import whenever the package is upgraded. Search uses `searchContent` and
maps results itself, because 2.5.3's `search()` throws on result pages that contain live
videos. Keep search probes and tests to a handful of queries: bursts from one IP get
YouTube's `google_abuse` redirect loop.

**Navigation.**
- Routes come from Mapbox Directions (`driving-traffic`, live traffic, Indonesian
  instructions, ETA refreshed every 5 minutes) when a token is built in. Otherwise, or when
  Mapbox fails, they come from the OSRM public servers.
- Search is Photon in both cases. Mapbox's terms tie its POI results to Mapbox maps and forbid
  storing them, which recent destinations need. For the same reason Mapbox routes are kept in
  memory only.
- The public OSRM servers allow at most one request per second, need a real User-Agent, and
  reject `exclude=toll`.
- Indonesian prompts go through Google TTS when the phone's default engine has no Indonesian
  voice, and music and video duck under each prompt.

**Map and rendering.**
- Tiles are standard OpenStreetMap tiles, darkened once as each tile is decoded
  (`DarkTileProvider`). A filter over the whole layer cost a full-screen pass every frame.
- Impeller is disabled in the manifest: on the A6+'s Adreno 506 Vulkan driver it drew the
  borders of widgets under a modal sheet on top of the sheet.
- The platform and UI threads are kept apart (`DisableMergedPlatformUIThread`), so plugins
  blocking Android's main thread (ExoPlayer release, TTS engine switch) do not freeze the
  UI. Recheck both settings when upgrading Flutter.
- Landscape is locked in the manifest and the status bar is hidden. Both are applied again
  when Android recreates the activity, because audio_service caches the Flutter engine and
  `main()` does not run again.

## Measuring smoothness on the phone

- **Frame pacing as the screen shows it:**
  1. Run `adb shell dumpsys SurfaceFlinger --latency-clear`.
  2. Do the gesture.
  3. Run `adb shell "dumpsys SurfaceFlinger --latency '<layer>'"`, using the app's
     `SurfaceView - io.github.rulyoctareza.kemudi...` layer from
     `dumpsys SurfaceFlinger --list`.

  Gaps between present times in 16.7 ms steps are missed refreshes. The buffer holds the last
  127 frames.
- **Frame costs:** build with `--dart-define=FRAME_LOG=true` and read `adb logcat` (tag
  `flutter`). It shows build and raster times per batch, frames over 16.7 ms, and `STALL`
  lines when the UI isolate was busy for more than 50 ms.
- **Tap with coordinates** (`adb shell input tap x y`) while measuring. UI automation tools
  turn on Flutter's semantics tree, which adds 7-25 ms per frame and spoils the figures.

## Releasing (maintainers)

Releases are built and signed by GitHub Actions (`.github/workflows/release.yml`) when a
version tag is pushed.

1. Raise `version` in `pubspec.yaml`: `X.Y.Z+N`, where `N` is the Android build number and
   must be higher than in every earlier release.
2. Add a `## [X.Y.Z] - YYYY-MM-DD` section at the top of `CHANGELOG.md` and its link at the
   bottom; the release notes are taken from it.
3. Commit, then `git tag vX.Y.Z && git push origin main vX.Y.Z`. A tag like `vX.Y.Z-rc.1`
   publishes a pre-release instead.

The workflow:
- checks that the tag matches the pubspec version, then runs analyze and the tests;
- builds one APK per ABI (arm64-v8a, armeabi-v7a);
- refuses to publish unless every APK is signed with the Kemudi key and the arm64 libraries
  are aligned for 16 KB memory pages;
- publishes the APKs with `SHA256SUMS.txt` and the certificate fingerprint.

The signing key lives in the repository secrets `ANDROID_KEYSTORE_BASE64` (the keystore,
base64) and `ANDROID_KEYSTORE_PASSWORD`; the key alias is `upload`. Keep an offline backup
of the keystore and its password. Without them no update can be installed over an existing
Kemudi, and every user would have to uninstall.

To sign a local release build with the same key, create `android/key.properties` (gitignored,
never commit it):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/absolute/path/to/kemudi-release.jks
```
