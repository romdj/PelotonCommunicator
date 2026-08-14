import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/voice_transport.dart';
import 'package:app/services/signaling_channel.dart';
import 'package:app/services/webrtc_service.dart';
import 'package:app/services/signaling_client.dart';

void main() {
  test('concrete services satisfy the RideSession interfaces', () {
    final SignalingChannel signaling =
        SignalingClient(serverUrl: 'ws://localhost:8080', userId: 'u1');
    final VoiceTransport transport =
        WebRTCService(signaling: signaling as SignalingClient);

    expect(signaling.peerCount, 0);
    expect(transport, isA<VoiceTransport>());
  });
}
