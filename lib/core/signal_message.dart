import 'dart:convert';

/// Messages échangés sur le WebSocket local pour établir la connexion WebRTC.
sealed class SignalMessage {
  const SignalMessage();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static SignalMessage decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      throw FormatException('JSON invalide', raw);
    }
    if (json is! Map<String, Object?>) throw FormatException('Objet attendu', raw);
    try {
      return switch (json['type']) {
        'hello' => HelloMessage(token: json['token'] as String),
        'offer' => SdpMessage(kind: SdpKind.offer, sdp: json['sdp'] as String),
        'answer' => SdpMessage(kind: SdpKind.answer, sdp: json['sdp'] as String),
        'ice' => IceMessage(
            candidate: json['candidate'] as String,
            sdpMid: json['sdpMid'] as String?,
            sdpMLineIndex: json['sdpMLineIndex'] as int?,
          ),
        'reject' => RejectMessage(reason: json['reason'] as String),
        _ => throw FormatException('Type inconnu', raw),
      };
    } on TypeError {
      throw FormatException('Champ manquant ou invalide', raw);
    }
  }
}

class HelloMessage extends SignalMessage {
  final String token;
  const HelloMessage({required this.token});

  @override
  Map<String, Object?> toJson() => {'type': 'hello', 'token': token};

  @override
  bool operator ==(Object other) => other is HelloMessage && other.token == token;
  @override
  int get hashCode => token.hashCode;
}

enum SdpKind { offer, answer }

class SdpMessage extends SignalMessage {
  final SdpKind kind;
  final String sdp;
  const SdpMessage({required this.kind, required this.sdp});

  @override
  Map<String, Object?> toJson() => {'type': kind.name, 'sdp': sdp};

  @override
  bool operator ==(Object other) => other is SdpMessage && other.kind == kind && other.sdp == sdp;
  @override
  int get hashCode => Object.hash(kind, sdp);
}

class IceMessage extends SignalMessage {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  const IceMessage({required this.candidate, this.sdpMid, this.sdpMLineIndex});

  @override
  Map<String, Object?> toJson() =>
      {'type': 'ice', 'candidate': candidate, 'sdpMid': sdpMid, 'sdpMLineIndex': sdpMLineIndex};

  @override
  bool operator ==(Object other) =>
      other is IceMessage &&
      other.candidate == candidate &&
      other.sdpMid == sdpMid &&
      other.sdpMLineIndex == sdpMLineIndex;
  @override
  int get hashCode => Object.hash(candidate, sdpMid, sdpMLineIndex);
}

class RejectMessage extends SignalMessage {
  final String reason;
  const RejectMessage({required this.reason});

  @override
  Map<String, Object?> toJson() => {'type': 'reject', 'reason': reason};

  @override
  bool operator ==(Object other) => other is RejectMessage && other.reason == reason;
  @override
  int get hashCode => reason.hashCode;
}
