import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/connection_watchdog.dart';
import '../core/pairing.dart';
import '../core/rtc_config.dart';
import '../core/signal_message.dart';

/// Le téléphone moniteur : se connecte à la caméra, montre le flux,
/// et passe en alarme si la connexion reste coupée trop longtemps.
class MonitorSession extends ChangeNotifier {
  final PairingInfo pairing;
  final ConnectionWatchdog watchdog;
  MonitorSession(this.pairing, {ConnectionWatchdog? watchdog})
      : watchdog = watchdog ?? ConnectionWatchdog();

  static const _reconnectDelay = Duration(seconds: 3);

  final RTCVideoRenderer video = RTCVideoRenderer();
  WatchdogState state = WatchdogState.waiting;
  String? rejectReason;

  WebSocket? _socket;
  RTCPeerConnection? _pc;
  Timer? _tick;
  Timer? _reconnect;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  Future<void> start() async {
    await video.initialize();
    watchdog.start(DateTime.now());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _evaluate());
    await _connect();
  }

  void _evaluate() {
    final next = watchdog.evaluate(DateTime.now());
    if (next != state) {
      state = next;
      notifyListeners();
    }
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final socket = await WebSocket.connect('ws://${pairing.host}:${pairing.port}')
          .timeout(const Duration(seconds: 5));
      _socket = socket;
      socket.listen(
        (data) => _enqueue(() => _onMessage(data)),
        // Un ancien socket fermé volontairement ne doit pas relancer une perte.
        onDone: () {
          if (identical(socket, _socket)) _enqueue(_onLost);
        },
        onError: (Object e) => debugPrint('[monitor] ws: $e'),
      );
      socket.add(HelloMessage(token: pairing.token).encode());
    } catch (e) {
      debugPrint('[monitor] connexion impossible: $e');
      await _onLost();
    }
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object e) {
      debugPrint('[monitor] erreur signaling: $e');
    });
  }

  Future<void> _onMessage(Object? data) async {
    if (data is! String) return;
    final SignalMessage msg;
    try {
      msg = SignalMessage.decode(data);
    } on FormatException {
      return;
    }
    switch (msg) {
      case SdpMessage(kind: SdpKind.offer, :final sdp):
        await _answer(sdp);
      case IceMessage(:final candidate, :final sdpMid, :final sdpMLineIndex):
        await _pc?.addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex));
      case RejectMessage(:final reason):
        rejectReason = reason;
        notifyListeners();
      default:
        break;
    }
  }

  Future<void> _answer(String offerSdp) async {
    await _closePeerConnection();
    final pc = await createPeerConnection(lanRtcConfig);
    _pc = pc;
    pc.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        video.srcObject = event.streams.first;
        notifyListeners();
      }
    };
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _socket?.add(IceMessage(
        candidate: c.candidate!,
        sdpMid: c.sdpMid,
        sdpMLineIndex: c.sdpMLineIndex,
      ).encode());
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          watchdog.markConnected(DateTime.now());
          Helper.setSpeakerphoneOn(true);
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _enqueue(_onLost);
        default:
          break;
      }
      _evaluate();
    };

    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _socket?.add(SdpMessage(kind: SdpKind.answer, sdp: answer.sdp!).encode());
  }

  /// Perte de connexion : le chien de garde compte le temps, on retente en boucle.
  Future<void> _onLost() async {
    watchdog.markLost(DateTime.now());
    _evaluate();
    await _closeAll();
    if (_disposed || rejectReason != null) return;
    _reconnect?.cancel();
    _reconnect = Timer(_reconnectDelay, _connect);
  }

  Future<void> _closePeerConnection() async {
    final pc = _pc;
    _pc = null;
    video.srcObject = null;
    await pc?.close();
  }

  Future<void> _closeAll() async {
    await _closePeerConnection();
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _tick?.cancel();
    _reconnect?.cancel();
    await _closeAll();
    await video.dispose();
    super.dispose();
  }
}
