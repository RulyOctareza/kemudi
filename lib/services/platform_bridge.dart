import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Speech-to-text of the platform: [listen] opens the recognizer and completes with the
/// heard text, or null when nothing was understood or it was cancelled. [available]
/// turns false once the phone turns out to have no recognizer, and the mic buttons hide.
typedef VoiceInput = ({
  ValueListenable<bool> available,
  Future<String?> Function() listen,
});

/// Android-side helpers on one method channel, implemented in `MainActivity.kt`:
/// picture-in-picture, sending the app to the background and speech recognition.
///
/// A singleton because the channel accepts one Dart handler; a second instance would
/// replace the first one's PiP-state callback.
class PlatformBridge {
  PlatformBridge._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final PlatformBridge _instance = PlatformBridge._internal();

  factory PlatformBridge() => _instance;

  static const MethodChannel _channel =
      MethodChannel('io.github.rulyoctareza.kemudi/pip');

  final ValueNotifier<bool> isInPip = ValueNotifier<bool>(false);

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged' && call.arguments is bool) {
      isInPip.value = call.arguments as bool;
    }
  }

  final ValueNotifier<bool> _speechAvailable = ValueNotifier<bool>(true);

  VoiceInput get voiceInput =>
      (available: _speechAvailable, listen: recognizeSpeech);

  /// Opens Android's speech recognizer (Indonesian) over the app and returns the text.
  Future<String?> recognizeSpeech() async {
    try {
      final text = (await _channel.invokeMethod<String>('recognizeSpeech'))?.trim();
      return text == null || text.isEmpty ? null : text;
    } catch (_) {
      // No recognizer installed (or no Android side at all): stop offering it.
      _speechAvailable.value = false;
      return null;
    }
  }

  Future<bool> enterPip() async {
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoPip(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoPip', {'enabled': enabled});
    } catch (_) {}
  }

  /// Moves the task behind other apps without finishing it, like Home does, so playback
  /// and the app state survive. Back on the dashboard uses this instead of closing.
  Future<void> minimize() async {
    try {
      await _channel.invokeMethod('minimize');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }
}
