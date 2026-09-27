/// Aucun serveur STUN/TURN : sur le même WiFi, les candidats "host" suffisent.
const Map<String, dynamic> lanRtcConfig = {
  'iceServers': <Map<String, dynamic>>[],
  'sdpSemantics': 'unified-plan',
};

/// 480p / 15 fps : assez pour surveiller, économe en batterie et en chaleur.
/// [rearCamera] : faux sur un ordinateur, qui n'a qu'une webcam frontale.
Map<String, dynamic> cameraConstraints({bool rearCamera = true}) => {
  'audio': {
    'echoCancellation': false,
    'noiseSuppression': false,
    'autoGainControl': true,
  },
  'video': {
    if (rearCamera) 'facingMode': 'environment',
    'width': {'ideal': 640},
    'height': {'ideal': 480},
    'frameRate': {'ideal': 15},
  },
};
