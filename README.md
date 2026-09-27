# BabyWatcher

Babycam à deux téléphones : l'un filme, l'autre surveille. Tout passe par le WiFi local,
sans serveur ni cloud.

## Architecture

```
📱 CAMÉRA (serveur)                               📱 MONITEUR (client)
 getUserMedia 480p/15fps                            scan du QR code
 HttpServer + WebSocket :8765  ◀── hello(token) ──  WebSocket.connect
 createOffer                   ── offer / ICE ──▶   createAnswer
                               ◀─ answer / ICE ──
 ═════════ flux WebRTC direct, chiffré (DTLS-SRTP) ════════▶ RTCVideoView
                                                    ConnectionWatchdog → alarme
```

- `lib/core/` : logique pure testée (appairage, messages, chien de garde, bip d'alarme).
- `lib/camera/` : capture, serveur de signaling local, pair WebRTC émetteur.
- `lib/monitor/` : scan QR, pair WebRTC récepteur, reconnexion automatique, alarme.

## Tester

1. Connecte les deux téléphones au même WiFi.
2. Lance `flutter run` sur chaque téléphone.
3. Sur le premier téléphone, choisis « Caméra ».
4. Sur le second téléphone, choisis « Moniteur » et scanne le QR code.
5. Coupe le WiFi du téléphone caméra : l'alarme doit sonner au bout de 10 s.

```bash
flutter test      # tests de la logique pure
flutter analyze   # analyse statique
```

## Limites du prototype

- Le téléphone caméra doit rester au premier plan (bouton lune : écran noir).
- Un seul moniteur à la fois.
- Le QR code change à chaque lancement de la caméra : il faut scanner de nouveau.
- Le moniteur doit rester au premier plan pour voir la vidéo ; l'alarme en arrière-plan n'est pas encore garantie.
- Pas de TURN : l'app fonctionne seulement sur le même WiFi (voulu).

## Releases et mise à jour automatique

Chaque push sur `main` lance `.github/workflows/android-release.yml` :

1. La CI lance `flutter analyze` et `flutter test`.
2. La CI met la version `1.0.<numéro du run>` (le `versionCode` augmente à chaque build).
3. La CI signe l'APK arm64 avec la clé release et publie la release `v1.0.N` avec l'empreinte SHA-256.

Au démarrage, l'app Android lit `releases/latest` du repo (`UPDATE_REPO`, par défaut
`gtosymph/BabyWatcher`). Si la version est plus récente, l'app propose la mise à jour,
télécharge l'APK, vérifie le SHA-256 et ouvre l'installateur Android.

**NOTE :** l'API publique des releases exige un repo public. Un repo privé renvoie 404
et l'app ne propose rien.

### Secrets GitHub requis

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Le fichier `.jks` encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Le mot de passe du keystore et de la clé |
| `ANDROID_KEY_ALIAS` | `babywatcher` |

**ATTENTION :** si la clé de signature est perdue, Android refuse toute mise à jour.
Chaque téléphone doit alors désinstaller l'app. Garde une sauvegarde de
`~/.babywatcher/` (keystore + mot de passe) dans un gestionnaire de mots de passe.

### Build release en local

Copie `~/.babywatcher/babywatcher-release.jks` et `key.properties` dans `android/`.
Sans ces fichiers, le build release utilise la clé debug.
