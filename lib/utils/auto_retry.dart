import 'dart:async';
import 'dart:io';

/// Whether the phone can reach YouTube's name server answer: a DNS lookup is cheap and
/// fails at once while the phone has no network, so it is polled during a retry wait.
Future<bool> hasNetwork() async {
  try {
    final found = await InternetAddress.lookup(
      'www.youtube.com',
    ).timeout(const Duration(seconds: 2));
    return found.isNotEmpty;
  } on Object {
    return false;
  }
}

/// Runs an action again after a growing delay, and at once when the network is back,
/// for failures that may pass by themselves (a tunnel, a dead spot, a cold start without
/// signal).
class AutoRetry {
  AutoRetry({
    required this.delays,
    this.probeEvery = const Duration(seconds: 3),
    Future<bool> Function()? online,
  }) : _online = online ?? hasNetwork;

  /// One entry per attempt; when they are used up, [schedule] returns false.
  final List<Duration> delays;
  final Duration probeEvery;
  final Future<bool> Function() _online;

  int _attempt = 0;
  Timer? _timer;
  Timer? _probe;

  /// Attempts scheduled since the last [reset].
  int get attempt => _attempt;

  /// Whether an attempt is waiting to run.
  bool get waiting => _timer?.isActive ?? false;

  /// Schedules [action] after the next delay, or sooner once the network answers.
  /// Returns false, scheduling nothing, when every delay has been used.
  bool schedule(void Function() action) {
    if (_attempt >= delays.length) return false;
    final delay = delays[_attempt++];
    void run() {
      cancel();
      action();
    }

    cancel();
    _timer = Timer(delay, run);
    _probe = Timer.periodic(probeEvery, (_) async {
      if (await _online() && waiting) run();
    });
    return true;
  }

  /// Runs the waiting attempt now, keeping the attempt count.
  bool runNow(void Function() action) {
    if (!waiting) return false;
    cancel();
    action();
    return true;
  }

  void cancel() {
    _timer?.cancel();
    _probe?.cancel();
  }

  /// Cancels any waiting attempt and starts counting from the first delay again.
  void reset() {
    cancel();
    _attempt = 0;
  }
}
