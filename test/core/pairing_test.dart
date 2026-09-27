import 'package:babycam/core/pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PairingInfo', () {
    test('encode puis parse redonne les mêmes valeurs', () {
      const info = PairingInfo(host: '192.168.1.42', port: 8765, token: 'abc123');
      final parsed = PairingInfo.parse(info.toUri());
      expect(parsed, info);
    });

    test('toUri utilise le schéma babycam', () {
      const info = PairingInfo(host: '10.0.0.5', port: 9000, token: 'tok');
      expect(info.toUri(), 'babycam://10.0.0.5:9000?t=tok');
    });

    test('parse refuse un autre schéma', () {
      expect(() => PairingInfo.parse('https://evil.com:8765?t=x'), throwsFormatException);
    });

    test('parse refuse un QR sans token', () {
      expect(() => PairingInfo.parse('babycam://192.168.1.2:8765'), throwsFormatException);
    });

    test('parse refuse une chaîne invalide', () {
      expect(() => PairingInfo.parse('pas un qr'), throwsFormatException);
    });

    test('generateToken crée des tokens longs et différents', () {
      final a = PairingInfo.generateToken();
      final b = PairingInfo.generateToken();
      expect(a.length, greaterThanOrEqualTo(32));
      expect(a, isNot(b));
    });
  });
}
