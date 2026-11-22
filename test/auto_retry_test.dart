import 'package:flutter_test/flutter_test.dart';
import 'package:kemudi/utils/auto_retry.dart';

void main() {
  test('runs after each delay until the delays are used up', () async {
    var runs = 0;
    final retry = AutoRetry(
      delays: const [Duration(milliseconds: 5), Duration(milliseconds: 5)],
      online: () async => false,
    );
    expect(retry.schedule(() => runs++), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(retry.schedule(() => runs++), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(runs, 2);
    expect(retry.schedule(() => runs++), isFalse);
    retry.reset();
    expect(retry.attempt, 0);
  });

  test('runs at once when the network answers before the delay ends', () async {
    var runs = 0;
    var online = false;
    final retry = AutoRetry(
      delays: const [Duration(seconds: 30)],
      probeEvery: const Duration(milliseconds: 5),
      online: () async => online,
    );
    retry.schedule(() => runs++);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(runs, 0);
    online = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(runs, 1);
    expect(retry.waiting, isFalse);
  });

  test('cancel stops a waiting attempt', () async {
    var runs = 0;
    final retry = AutoRetry(
      delays: const [Duration(milliseconds: 5)],
      online: () async => true,
      probeEvery: const Duration(milliseconds: 1),
    );
    retry.schedule(() => runs++);
    retry.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(runs, 0);
  });
}
