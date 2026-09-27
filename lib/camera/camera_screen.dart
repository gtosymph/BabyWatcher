import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camera_session.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _session = CameraSession();
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _session.addListener(_refresh);
    _session.start();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    WakelockPlus.disable();
    _session.removeListener(_refresh);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écran noir : l'app reste au premier plan (obligatoire sur iOS) sans éclairer la chambre.
    if (_dimmed) {
      return GestureDetector(
        onDoubleTap: () => setState(() => _dimmed = false),
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Text('Double-tape pour rallumer',
                style: TextStyle(color: Color(0xFF222222))),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caméra'),
        actions: [
          IconButton(
            tooltip: 'Écran noir',
            icon: const Icon(Icons.nightlight_round),
            onPressed: () => setState(() => _dimmed = true),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final pairing = _session.pairing;
    return switch (_session.status) {
      CameraStatus.starting => const Center(child: CircularProgressIndicator()),
      CameraStatus.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_session.errorMessage ?? 'Erreur', textAlign: TextAlign.center),
          ),
        ),
      _ => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusChip(status: _session.status),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_session.preview,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
            if (pairing != null) ...[
              const SizedBox(height: 24),
              const Text('Scanne ce code avec le téléphone moniteur',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(data: pairing.toUri(), size: 220),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText('${pairing.host}:${pairing.port}', textAlign: TextAlign.center),
            ],
          ],
        ),
    };
  }
}

class _StatusChip extends StatelessWidget {
  final CameraStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CameraStatus.streaming => ('Moniteur connecté', Colors.green),
      CameraStatus.waitingMonitor => ('En attente du moniteur', Colors.orange),
      _ => ('…', Colors.grey),
    };
    return Center(
      child: Chip(
        avatar: Icon(Icons.circle, color: color, size: 14),
        label: Text(label),
      ),
    );
  }
}
