import 'dart:io';

/// Trouve l'adresse IPv4 privée du téléphone sur le WiFi.
Future<String?> findLocalIp() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final candidates = [
    for (final iface in interfaces)
      for (final addr in iface.addresses)
        if (!addr.isLoopback && _isPrivate(addr.address)) (iface.name, addr.address),
  ];
  if (candidates.isEmpty) return null;
  // Le WiFi s'appelle en0 sur iOS et wlan0 sur Android.
  final wifi = candidates.where((c) => c.$1 == 'en0' || c.$1.startsWith('wlan'));
  return (wifi.isNotEmpty ? wifi.first : candidates.first).$2;
}

bool _isPrivate(String ip) {
  final parts = ip.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.contains(null)) return false;
  final a = parts[0]!, b = parts[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}
