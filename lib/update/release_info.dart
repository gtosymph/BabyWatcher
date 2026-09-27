import 'app_version.dart';

/// La dernière release publiée sur GitHub, réduite à ce dont l'app a besoin.
class ReleaseInfo {
  final AppVersion version;
  final String apkUrl;
  final String notes;

  /// Empreinte SHA-256 de l'APK, écrite par la CI dans les notes de release.
  final String? sha256;

  const ReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    this.sha256,
  });

  static final _sha256Pattern = RegExp(r'SHA-256[^:]*:\s*`?([a-f0-9]{64})`?');

  bool isNewerThan(AppVersion current) => version > current;

  /// Lit la réponse de `GET /repos/{owner}/{repo}/releases/latest`.
  factory ReleaseInfo.fromGitHub(Map<String, Object?> json) {
    final tag = json['tag_name'];
    if (tag is! String) throw const FormatException('Release sans tag_name');

    final apks = <String, String>{
      for (final a in (json['assets'] as List<Object?>? ?? const []))
        if (a is Map<String, Object?> &&
            a['name'] is String &&
            (a['name'] as String).endsWith('.apk') &&
            a['browser_download_url'] is String)
          a['name'] as String: a['browser_download_url'] as String,
    };
    if (apks.isEmpty) throw FormatException('Release sans APK', tag);

    final name = apks.keys.firstWhere((n) => n.contains('arm64'), orElse: () => apks.keys.first);
    final url = apks[name]!;
    // L'app installe seulement un APK servi par GitHub, jamais une URL arbitraire.
    if (!url.startsWith('https://github.com/')) {
      throw FormatException('URL d\'APK hors GitHub', url);
    }

    final notes = json['body'] as String? ?? '';
    return ReleaseInfo(
      version: AppVersion.parse(tag),
      apkUrl: url,
      notes: notes,
      sha256: _sha256Pattern.firstMatch(notes)?.group(1),
    );
  }
}
