import 'package:babycam/update/app_version.dart';
import 'package:babycam/update/release_info.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> asset(String name) => {
      'name': name,
      'browser_download_url': 'https://github.com/o/r/releases/download/v1.0.5/$name',
    };

void main() {
  group('ReleaseInfo.fromGitHub', () {
    test('lit la version, les notes et l\'APK arm64', () {
      final info = ReleaseInfo.fromGitHub({
        'tag_name': 'v1.0.5',
        'body': 'Ajout de l\'alarme',
        'draft': false,
        'prerelease': false,
        'assets': [asset('babywatcher-1.0.5-arm64.apk'), asset('checksums.txt')],
      });
      expect(info.version, const AppVersion(1, 0, 5));
      expect(info.notes, 'Ajout de l\'alarme');
      expect(info.apkUrl, endsWith('babywatcher-1.0.5-arm64.apk'));
    });

    test('préfère l\'APK arm64 quand plusieurs APK existent', () {
      final info = ReleaseInfo.fromGitHub({
        'tag_name': 'v1.0.5',
        'assets': [asset('babywatcher-1.0.5-armv7.apk'), asset('babywatcher-1.0.5-arm64.apk')],
      });
      expect(info.apkUrl, endsWith('arm64.apk'));
    });

    test('refuse une release sans APK', () {
      expect(
        () => ReleaseInfo.fromGitHub({'tag_name': 'v1.0.5', 'assets': [asset('notes.txt')]}),
        throwsFormatException,
      );
    });

    test('refuse une URL qui ne vient pas de GitHub', () {
      expect(
        () => ReleaseInfo.fromGitHub({
          'tag_name': 'v1.0.5',
          'assets': [
            {'name': 'x-arm64.apk', 'browser_download_url': 'https://evil.example/x-arm64.apk'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('lit la somme SHA-256 écrite par la CI dans les notes', () {
      final hash = 'a' * 64;
      final info = ReleaseInfo.fromGitHub({
        'tag_name': 'v1.0.5',
        'body': 'Changements\n\nSHA-256 (arm64): `$hash`',
        'assets': [asset('babywatcher-1.0.5-arm64.apk')],
      });
      expect(info.sha256, hash);
    });

    test('sha256 est nul si les notes n\'en contiennent pas', () {
      final info = ReleaseInfo.fromGitHub({
        'tag_name': 'v1.0.5',
        'assets': [asset('babywatcher-1.0.5-arm64.apk')],
      });
      expect(info.sha256, isNull);
    });

    test('refuse un JSON sans tag', () {
      expect(() => ReleaseInfo.fromGitHub({'assets': []}), throwsFormatException);
    });
  });

  group('ReleaseInfo.isNewerThan', () {
    final info = ReleaseInfo(
      version: const AppVersion(1, 0, 5),
      apkUrl: 'https://github.com/x.apk',
      notes: '',
    );
    test('vrai si la release est plus récente', () {
      expect(info.isNewerThan(const AppVersion(1, 0, 4)), isTrue);
    });
    test('faux si la version est identique', () {
      expect(info.isNewerThan(const AppVersion(1, 0, 5)), isFalse);
    });
  });
}
