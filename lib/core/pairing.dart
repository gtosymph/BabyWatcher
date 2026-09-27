import 'dart:math';

/// Informations d'appairage partagées par QR code : où joindre la caméra
/// et le secret qui prouve que le moniteur a vu l'écran de la caméra.
class PairingInfo {
  static const scheme = 'babycam';
  static const defaultPort = 8765;

  final String host;
  final int port;
  final String token;

  const PairingInfo({required this.host, required this.port, required this.token});

  String toUri() => '$scheme://$host:$port?t=$token';

  static PairingInfo parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host.isEmpty || !uri.hasPort) {
      throw FormatException('QR babycam invalide', raw);
    }
    final token = uri.queryParameters['t'];
    if (token == null || token.isEmpty) {
      throw FormatException('QR babycam sans token', raw);
    }
    return PairingInfo(host: uri.host, port: uri.port, token: token);
  }

  static String generateToken([Random? random]) {
    final rng = random ?? Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
  }

  @override
  bool operator ==(Object other) =>
      other is PairingInfo && other.host == host && other.port == port && other.token == token;

  @override
  int get hashCode => Object.hash(host, port, token);
}
