import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps uncaught errors, and playback failures the driver saw, in a file on the phone,
/// so a problem on the road can be read afterwards:
/// `adb pull /sdcard/Android/data/com.carheadunit.youtube_car_headunit/files/errors.log`.
///
/// Nothing leaves the phone. Writes are appended in order off the UI's way; the file is
/// capped at [_maxBytes] and the previous one is kept as `errors.old.log`.
class ErrorLog {
  ErrorLog._();

  static const _maxBytes = 256 * 1024;
  static const _stackLines = 25;

  static Future<File?>? _file;
  static Future<void> _writes = Future.value();

  /// Routes uncaught Flutter and Dart errors here. Returns at once; the file is found
  /// in the background and entries recorded before then wait for it.
  static void install() {
    _file = _open();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      record(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught error: $error');
      record(error, stack, context: 'uncaught');
      return true;
    };
  }

  static Future<File?> _open() async {
    try {
      final dir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationSupportDirectory();
      return dir == null ? null : File('${dir.path}/errors.log');
    } catch (e) {
      debugPrint('Error log unavailable: $e');
      return null;
    }
  }

  /// Appends one entry; a no-op before [install] (widget tests).
  static void record(Object error, StackTrace? stack, {String? context}) {
    final file = _file;
    if (file == null) return;
    final lines = [
      '${DateTime.now().toIso8601String()} ${context ?? ''}'.trimRight(),
      '$error',
      if (stack != null)
        ...stack.toString().trimRight().split('\n').take(_stackLines),
      '',
    ];
    final entry = '${lines.join('\n')}\n';
    _writes = _writes.then((_) => _append(file, entry));
  }

  static Future<void> _append(Future<File?> pending, String entry) async {
    try {
      final file = await pending;
      if (file == null) return;
      if (await file.exists() && await file.length() > _maxBytes) {
        await file.rename('${file.parent.path}/errors.old.log');
      }
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Error log write failed: $e');
    }
  }
}
