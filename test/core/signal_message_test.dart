import 'package:babycam/core/signal_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignalMessage', () {
    final cases = <SignalMessage>[
      const HelloMessage(token: 'secret'),
      const SdpMessage(kind: SdpKind.offer, sdp: 'v=0...'),
      const SdpMessage(kind: SdpKind.answer, sdp: 'v=0 answer'),
      const IceMessage(candidate: 'candidate:1 1 UDP ...', sdpMid: '0', sdpMLineIndex: 0),
      const RejectMessage(reason: 'bad token'),
    ];

    for (final msg in cases) {
      test('aller-retour JSON pour ${msg.runtimeType}', () {
        expect(SignalMessage.decode(msg.encode()), msg);
      });
    }

    test('decode refuse un type inconnu', () {
      expect(() => SignalMessage.decode('{"type":"zzz"}'), throwsFormatException);
    });

    test('decode refuse un JSON invalide', () {
      expect(() => SignalMessage.decode('{oops'), throwsFormatException);
    });

    test('decode refuse un champ manquant', () {
      expect(() => SignalMessage.decode('{"type":"hello"}'), throwsFormatException);
    });
  });
}
