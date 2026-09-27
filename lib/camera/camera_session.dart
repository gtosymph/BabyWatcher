import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/network.dart';
import '../core/pairing.dart';
import '../core/rtc_config.dart';
import '../core/signal_message.dart';

enum CameraStatus { starting, waitingMonitor, streaming, error }

/// Le téléphone caméra : capture, serveur de signaling local et pair WebRTC.
class CameraSession extends ChangeNotifier {
  final int port;
  CameraSession({this.port = PairingInfo.defaultPort});

  final RTCVideoRenderer preview = RTCVideoRenderer();
  CameraStatus status = CameraStatus.starting;
  PairingInfo? pairing;
  String? errorMessage;

  MediaStream? _stream;
  HttpServer? _server;
  WebSocket? _socket;
  RTCPeerConnection? _pc;
  Future<void> _queue = Future.value();
  final String _token = PairingInfo.generateToken();

  Future<void> start() async {
    try {
      await preview.initialize();
      _stream = await navigator.mediaDevices.getUserMedia(
        cameraConstraints(rearCamera: Platform.isAndroid || Platform.isIOS),
      );
      preview.srcObject = _stream;

      final ip = await findLocalIp();
      if (ip == null) throw StateError('Pas de WiFi : connecte le téléphone au réseau local.');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_onRequest, onError: (Object e) => debugPrint('[camera] http: $e'));

      pairing = PairingInfo(host: ip, port: port, token: _token);
      _setStatus(CameraStatus.waitingMonitor);
    } catch (e) {
      errorMessage = e.toString();
      _setStatus(CameraStatus.error);
    }
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen(
      (data) => _enqueue(() => _onMessage(socket, data)),
      onDone: () => _enqueue(() => _onSocketClosed(socket)),
      onError: (Object e) => debugPrint('[camera] ws: $e'),
    );
  }

  /// Traite les messages un par un : un candidat ICE ne doit pas passer avant la réponse SDP.
  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object e) {
      debugPrint('[camera] erreur signaling: $e');
    });
  }

  Future<void> _onMessage(WebSocket socket, Object? data) async {
    if (data is! String) return;
    final SignalMessage msg;
    try {
      msg = SignalMessage.decode(data);
    } on FormatException {
      return;
    }
    switch (msg) {
      case HelloMessage(:final token):
        if (token != _token) {
          socket.add(const RejectMessage(reason: 'token invalide').encode());
          await socket.close();
          return;
        }
        await _acceptMonitor(socket);
      case SdpMessage(kind: SdpKind.answer, :final sdp) when identical(socket, _socket):
        await _pc?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      case IceMessage(:final candidate, :final sdpMid, :final sdpMLineIndex)
          when identical(socket, _socket):
        await _pc?.addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex));
      default:
        break;
    }
  }

  /// Prototype : un seul moniteur à la fois, le dernier arrivé remplace le précédent.
  Future<void> _acceptMonitor(WebSocket socket) async {
    await _closePeer();
    _socket = socket;
    final pc = await createPeerConnection(lanRtcConfig);
    _pc = pc;

    for (final track in _stream!.getTracks()) {
      await pc.addTrack(track, _stream!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      socket.add(IceMessage(
        candidate: c.candidate!,
        sdpMid: c.sdpMid,
        sdpMLineIndex: c.sdpMLineIndex,
      ).encode());
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setStatus(CameraStatus.streaming);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _setStatus(CameraStatus.waitingMonitor);
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    socket.add(SdpMessage(kind: SdpKind.offer, sdp: offer.sdp!).encode());
  }

  Future<void> _onSocketClosed(WebSocket socket) async {
    if (!identical(socket, _socket)) return;
    await _closePeer();
    _setStatus(CameraStatus.waitingMonitor);
  }

  Future<void> _closePeer() async {
    final pc = _pc;
    _pc = null;
    await pc?.close();
    final old = _socket;
    _socket = null;
    await old?.close();
  }

  void _setStatus(CameraStatus value) {
    status = value;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _closePeer();
    await _server?.close(force: true);
    for (final t in _stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _stream?.dispose();
    preview.srcObject = null;
    await preview.dispose();
    super.dispose();
  }
}
