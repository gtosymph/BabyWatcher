import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/pairing.dart';
import 'monitor_screen.dart';

/// Scan du QR code affiché par la caméra.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool _done = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      try {
        final info = PairingInfo.parse(raw);
        _done = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MonitorScreen(pairing: info)),
        );
        return;
      } on FormatException {
        setState(() => _error = 'Ce QR code ne vient pas d\'une caméra Babycam.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appairer la caméra')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Card(
                child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
              ),
            ),
        ],
      ),
    );
  }
}
