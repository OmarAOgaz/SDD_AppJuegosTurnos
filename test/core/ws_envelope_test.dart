import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/models/ws_envelope.dart';

void main() {
  group('WsEnvelope', () {
    test('round-trip encode/decode', () {
      const original = WsEnvelope(
        type: 'PING',
        payload: {'deviceId': 'abc'},
      );
      final decoded = WsEnvelope.decode(original.encode());
      expect(decoded.type, 'PING');
      expect(decoded.payload['deviceId'], 'abc');
    });

    test('rejects invalid JSON root', () {
      expect(() => WsEnvelope.decode('"not-an-object"'), throwsFormatException);
    });
  });
}
