import 'dart:math';
import 'dart:typed_data';

/// Crée un bip d'alarme (deux tons alternés) au format WAV PCM 16 bits mono.
/// Le son est créé en mémoire : l'app n'embarque aucun fichier audio.
Uint8List buildAlarmWav({
  int sampleRate = 22050,
  Duration duration = const Duration(milliseconds: 800),
}) {
  final samples = sampleRate * duration.inMilliseconds ~/ 1000;
  final dataSize = samples * 2;
  final bytes = ByteData(44 + dataSize);

  void ascii(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // taille du bloc fmt
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // octets par seconde
  bytes.setUint16(32, 2, Endian.little); // octets par échantillon
  bytes.setUint16(34, 16, Endian.little); // bits par échantillon
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  const amplitude = 30000;
  final half = samples ~/ 2;
  for (var i = 0; i < samples; i++) {
    final freq = i < half ? 880.0 : 1320.0;
    final value = (amplitude * sin(2 * pi * freq * i / sampleRate)).round();
    bytes.setInt16(44 + i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
