import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_version.dart';
import 'release_info.dart';

/// Repo GitHub dont l'app lit les releases. Modifiable au build :
/// `--dart-define=UPDATE_REPO=owner/repo`.
const updateRepo = String.fromEnvironment('UPDATE_REPO', defaultValue: 'gtosymph/BabyWatcher');

class UpdateService {
  final http.Client _client;
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// L'auto-update concerne seulement l'APK Android installé hors store.
  static bool get isSupported => Platform.isAndroid;

  Future<AppVersion> currentVersion() async =>
      AppVersion.parse((await PackageInfo.fromPlatform()).version);

  /// Renvoie la release si elle est plus récente que l'app, sinon null.
  Future<ReleaseInfo?> findUpdate() async {
    final response = await _client
        .get(
          Uri.https('api.github.com', '/repos/$updateRepo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    // 404 : pas encore de release, ou repo privé.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw HttpException('GitHub a répondu ${response.statusCode}');
    }
    final release = ReleaseInfo.fromGitHub(jsonDecode(response.body) as Map<String, Object?>);
    return release.isNewerThan(await currentVersion()) ? release : null;
  }

  /// Télécharge l'APK, vérifie son empreinte, puis ouvre l'installateur Android.
  Stream<OtaEvent> install(ReleaseInfo release) => OtaUpdate().execute(
        release.apkUrl,
        destinationFilename: 'babywatcher-${release.version}.apk',
        sha256checksum: release.sha256,
      );
}
