import 'package:babycam/core/connection_watchdog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grace = Duration(seconds: 10);
  final t0 = DateTime(2026, 9, 27, 3, 0, 0);

  WatchdogState at(ConnectionWatchdog w, int seconds) =>
      w.evaluate(t0.add(Duration(seconds: seconds)));

  group('ConnectionWatchdog', () {
    test('état initial : en attente, pas d\'alarme', () {
      final w = ConnectionWatchdog(grace: grace);
      expect(at(w, 0), WatchdogState.waiting);
    });

    test('connecté après markConnected', () {
      final w = ConnectionWatchdog(grace: grace)..markConnected(t0);
      expect(at(w, 1), WatchdogState.connected);
    });

    test('perte courte : état instable sans alarme', () {
      final w = ConnectionWatchdog(grace: grace)
        ..markConnected(t0)
        ..markLost(t0.add(const Duration(seconds: 1)));
      expect(at(w, 5), WatchdogState.unstable);
    });

    test('perte plus longue que la grâce : alarme', () {
      final w = ConnectionWatchdog(grace: grace)
        ..markConnected(t0)
        ..markLost(t0.add(const Duration(seconds: 1)));
      expect(at(w, 11), WatchdogState.alarm);
    });

    test('reconnexion avant la grâce : pas d\'alarme', () {
      final w = ConnectionWatchdog(grace: grace)
        ..markConnected(t0)
        ..markLost(t0.add(const Duration(seconds: 1)))
        ..markConnected(t0.add(const Duration(seconds: 4)));
      expect(at(w, 30), WatchdogState.connected);
    });

    test('markLost répété ne repousse pas le début de la perte', () {
      final w = ConnectionWatchdog(grace: grace)
        ..markConnected(t0)
        ..markLost(t0.add(const Duration(seconds: 1)))
        ..markLost(t0.add(const Duration(seconds: 8)));
      expect(at(w, 11), WatchdogState.alarm);
    });

    test('jamais connecté après la grâce : alarme (la caméra ne répond pas)', () {
      final w = ConnectionWatchdog(grace: grace)..start(t0);
      expect(at(w, 11), WatchdogState.alarm);
    });
  });
}
