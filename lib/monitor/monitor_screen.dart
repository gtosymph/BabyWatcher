import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/connection_watchdog.dart';
import '../core/pairing.dart';
import 'alarm_player.dart';
import 'monitor_session.dart';

class MonitorScreen extends StatefulWidget {
  final PairingInfo pairing;
  const MonitorScreen({super.key, required this.pairing});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final MonitorSession _session = MonitorSession(widget.pairing);
  final _alarm = AlarmPlayer();
  DateTime? _mutedUntil;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _session.addListener(_onChange);
    _session.start();
  }

  void _onChange() {
    final muted = _mutedUntil != null && DateTime.now().isBefore(_mutedUntil!);
    if (_session.state == WatchdogState.alarm && !muted) {
      _alarm.play();
    } else {
      _alarm.stop();
    }
    if (_session.state == WatchdogState.connected) _mutedUntil = null;
    setState(() {});
  }

  void _muteOneMinute() {
    _mutedUntil = DateTime.now().add(const Duration(minutes: 1));
    _alarm.stop();
    setState(() {});
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _session.removeListener(_onChange);
    _session.dispose();
    _alarm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _session.state;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Moniteur'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(_session.video,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
          Positioned(top: 12, left: 0, right: 0, child: Center(child: _Banner(state: state))),
          if (_session.rejectReason != null)
            const _Overlay(
              color: Color(0xCC444444),
              title: 'Appairage refusé',
              message: 'La caméra a changé de code. Scanne le nouveau QR code.',
            ),
          if (state == WatchdogState.alarm)
            _Overlay(
              color: const Color(0xEEB00020),
              title: 'CONNEXION PERDUE',
              message: 'La caméra ne répond plus. Va vérifier les bébés.',
              action: FilledButton.tonal(
                onPressed: _muteOneMinute,
                child: const Text('Couper le son 1 min'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final WatchdogState state;
  const _Banner({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      WatchdogState.waiting => ('Connexion à la caméra…', Colors.orange),
      WatchdogState.connected => ('En direct', Colors.green),
      WatchdogState.unstable => ('Connexion instable…', Colors.orange),
      WatchdogState.alarm => ('Connexion perdue', Colors.red),
    };
    return Chip(avatar: Icon(Icons.circle, color: color, size: 14), label: Text(label));
  }
}

class _Overlay extends StatelessWidget {
  final Color color;
  final String title;
  final String message;
  final Widget? action;
  const _Overlay({required this.color, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
