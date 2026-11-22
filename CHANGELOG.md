# Changelog

All notable changes to Kemudi. Versions are `MAJOR.MINOR.PATCH`; the number after `+` in
`pubspec.yaml` is the Android build number and only ever goes up.

## [2.0.0] - 2026-11-22

First public release. Kemudi was a private build called "YouTube Car" before; it is a new
app on Android (id `io.github.rulyoctareza.kemudi`), so it installs beside the old one and
starts with fresh settings.

### Changed
- New name, app id and steering-wheel icon; licensed under GPL-3.0.
- APKs for 64-bit (arm64-v8a) and 32-bit (armeabi-v7a) ARM phones, signed with the Kemudi
  release key.
- Release builds route with the public OSRM servers; Mapbox live traffic needs a build with
  your own token (see the README).
- Menus are now Beranda, Peta, YouTube and Musik; Autoplay reads "Putar otomatis" and the
  route choice "Lalin" (live traffic) or "Biasa".
- Roads stand out on the dark map: minor roads grey, major roads amber.
- Smaller fixes for the driver: the destination search opens with the keyboard ready, a
  larger seek thumb, a labelled Musik button on the inline player, the "Lanjutkan" tile shows
  two lines of title, and the guidance banner's "Lalu" line appears only near the maneuver.

### Added
- Voice search: a microphone in the YouTube and place search fields opens Google's speech
  dialog (no extra permission).
- The last three YouTube searches as chips under the search field.
- 10-second jump buttons labelled "10", also in Fullscreen.
- A status-bar icon for the playback and navigation notifications.

### Carried over from the private builds
- Dashboard with a live map and what is playing.
- YouTube search, categories, Live and paging without ads; SponsorBlock auto-skip; 360p,
  480p/720p (HLS) and Audio Only; picture-in-picture and background playback; resume where
  you left off; autoplay.
- Steering-wheel and Bluetooth media buttons through the media session; Musik mode with
  large controls and swipe to skip.
- In-app navigation: search as you type, route preview with alternatives, Indonesian voice
  prompts, rerouting, guidance in the background, hand-off to Google Maps.
- Automatic recovery after a network drop, and an error log on the phone.

[2.0.0]: https://github.com/RulyOctareza/kemudi/releases/tag/v2.0.0
