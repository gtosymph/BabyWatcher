import 'package:babycam/update/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion', () {
    test('parse accepte le préfixe v du tag', () {
      expect(AppVersion.parse('v1.0.12'), const AppVersion(1, 0, 12));
    });

    test('parse ignore le suffixe +build', () {
      expect(AppVersion.parse('1.2.3+45'), const AppVersion(1, 2, 3));
    });

    test('parse refuse une chaîne invalide', () {
      expect(() => AppVersion.parse('latest'), throwsFormatException);
      expect(() => AppVersion.parse('1.2'), throwsFormatException);
    });

    test('compare numériquement, pas alphabétiquement', () {
      expect(AppVersion.parse('1.0.10') > AppVersion.parse('1.0.9'), isTrue);
      expect(AppVersion.parse('2.0.0') > AppVersion.parse('1.9.99'), isTrue);
      expect(AppVersion.parse('1.0.3') > AppVersion.parse('1.0.3'), isFalse);
    });

    test('toString montre la forme x.y.z', () {
      expect(const AppVersion(1, 0, 7).toString(), '1.0.7');
    });
  });
}
