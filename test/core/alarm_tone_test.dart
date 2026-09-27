import 'dart:typed_data';

import 'package:babycam/core/alarm_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAlarmWav', () {
    final wav = buildAlarmWav(sampleRate: 8000, duration: const Duration(milliseconds: 500));
    final data = ByteData.sublistView(wav);

    String ascii(int offset) => String.fromCharCodes(wav.sublist(offset, offset + 4));

    test('en-tête RIFF/WAVE valide', () {
      expect(ascii(0), 'RIFF');
      expect(ascii(8), 'WAVE');
      expect(ascii(12), 'fmt ');
      expect(ascii(36), 'data');
    });

    test('PCM 16 bits mono au bon taux', () {
      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), 8000);
      expect(data.getUint16(34, Endian.little), 16);
    });

    test('taille cohérente avec la durée', () {
      const samples = 4000; // 0,5 s à 8 kHz
      expect(data.getUint32(40, Endian.little), samples * 2);
      expect(wav.length, 44 + samples * 2);
      expect(data.getUint32(4, Endian.little), wav.length - 8);
    });

    test('le signal n\'est pas silencieux', () {
      final peak = List.generate(4000, (i) => data.getInt16(44 + i * 2, Endian.little).abs())
          .reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(20000));
    });
  });
}
