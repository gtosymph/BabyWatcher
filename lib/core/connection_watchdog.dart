enum WatchdogState { waiting, connected, unstable, alarm }

/// Décide quand une perte de connexion devient une alarme.
/// Logique pure et horloge injectée : testable sans timer.
class ConnectionWatchdog {
  final Duration grace;
  DateTime? _startedAt;
  DateTime? _lostSince;
  bool _everConnected = false;

  ConnectionWatchdog({this.grace = const Duration(seconds: 10)});

  /// Début de la surveillance : sans connexion au bout de [grace], l'alarme sonne.
  void start(DateTime now) => _startedAt ??= now;

  void markConnected(DateTime now) {
    _everConnected = true;
    _lostSince = null;
  }

  void markLost(DateTime now) => _lostSince ??= now;

  WatchdogState evaluate(DateTime now) {
    if (!_everConnected) {
      final started = _startedAt;
      if (started != null && now.difference(started) >= grace) return WatchdogState.alarm;
      return WatchdogState.waiting;
    }
    final lost = _lostSince;
    if (lost == null) return WatchdogState.connected;
    return now.difference(lost) >= grace ? WatchdogState.alarm : WatchdogState.unstable;
  }
}
