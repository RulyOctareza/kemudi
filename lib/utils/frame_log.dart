import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// On only in builds made with `--dart-define=FRAME_LOG=true`; otherwise the code is
/// compiled out.
const bool kFrameLog = bool.fromEnvironment('FRAME_LOG');

/// With FRAME_LOG in a profile build, `--dart-define=BUILD_PROFILE=true` also prints the
/// widget builds and layouts of 3 ms or more (in-app timeline collection, which release
/// builds do not have), so a slow frame can be traced to the widgets that built in it.
const bool kBuildProfile = bool.fromEnvironment('BUILD_PROFILE');

/// Prints frame costs to the device log (tag `flutter`) for measuring smoothness on the
/// phone: once per batch the UI-thread (build) and raster-thread times, plus every frame
/// that missed the 16.7 ms budget of a 60 Hz screen, and UI-isolate stalls over 50 ms.
void startFrameLog() {
  if (!kFrameLog) return;
  final profileBuilds = kBuildProfile && !kReleaseMode;
  if (profileBuilds) {
    debugProfileBuildsEnabled = true;
    debugProfileLayoutsEnabled = true;
    FlutterTimeline.debugCollectionEnabled = true;
  }
  // Late 16 ms timer ticks show the UI isolate busy outside frames as well (response
  // parsing, TLS handshakes), which frame timings cannot see.
  final clock = Stopwatch()..start();
  var last = 0;
  Timer.periodic(const Duration(milliseconds: 16), (_) {
    final now = clock.elapsedMilliseconds;
    if (now - last > 50) debugPrint('STALL ${now - last} ms');
    last = now;
  });
  SchedulerBinding.instance.addTimingsCallback((timings) {
    final build = [for (final t in timings) t.buildDuration.inMicroseconds / 1000]
      ..sort();
    final raster = [for (final t in timings) t.rasterDuration.inMicroseconds / 1000]
      ..sort();
    String stats(List<double> ms) =>
        'p50 ${ms[ms.length ~/ 2].toStringAsFixed(1)} '
        'p90 ${ms[(ms.length * 9) ~/ 10].toStringAsFixed(1)} '
        'max ${ms.last.toStringAsFixed(1)}';
    debugPrint(
      'FRAMES n=${timings.length} build[${stats(build)}] raster[${stats(raster)}]',
    );
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000;
      final r = t.rasterDuration.inMicroseconds / 1000;
      if (b > 16.7 || r > 16.7) {
        debugPrint(
          'SLOW build ${b.toStringAsFixed(1)} raster ${r.toStringAsFixed(1)} '
          'total ${(t.totalSpan.inMicroseconds / 1000).toStringAsFixed(1)}',
        );
      }
    }
    if (profileBuilds) _printSlowBlocks();
  });
}

/// Timed builds and layouts since the last call that took 3 ms or more, in time order;
/// a block's time includes the blocks nested in it.
void _printSlowBlocks() {
  final blocks = FlutterTimeline.debugCollect().timedBlocks;
  if (blocks.isEmpty) return;
  final t0 = blocks.first.start;
  for (final b in blocks) {
    if (b.duration < 3000) continue;
    debugPrint(
      'BLOCK t=${((b.start - t0) / 1000).toStringAsFixed(0)} '
      '${(b.duration / 1000).toStringAsFixed(1)} ms ${b.name}',
    );
  }
}

/// Prints `MARK <label>` in FRAME_LOG builds, so app events line up with the frame and
/// stall lines in logcat; compiled out otherwise.
void frameMark(String label) {
  if (kFrameLog) debugPrint('MARK $label');
}
