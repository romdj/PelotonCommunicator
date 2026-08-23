import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/voice_transport.dart';
import 'package:app/services/signaling_channel.dart';
import 'package:app/services/webrtc_service.dart';
import 'package:app/services/signaling_client.dart';
import 'package:app/services/ptt_service.dart';
import 'package:app/services/ride_session.dart';
import '../support/fakes.dart';

void main() {
  test('concrete services satisfy the RideSession interfaces', () {
    final SignalingChannel signaling =
        SignalingClient(serverUrl: 'ws://localhost:8080', userId: 'u1');
    final VoiceTransport transport =
        WebRTCService(signaling: signaling as SignalingClient);

    expect(signaling.peerCount, 0);
    expect(transport, isA<VoiceTransport>());
  });

  group('RideSession', () {
    const channel = MethodChannel('com.example.peloton/ptt');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> drain() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('join connects, comes up muted, and joins the room', () async {
      final ptt = PTTService(recorder: FakeRecorder());
      final transport = FakeVoiceTransport();
      final signaling = FakeSignaling();
      final session =
          RideSession(ptt: ptt, transport: transport, signaling: signaling);

      await session.join('BBB:A1');
      await drain();

      expect(signaling.connectCount, 1);
      expect(transport.initCount, 1);
      expect(transport.lastMuted, true, reason: 'must be muted by default');
      expect(signaling.joinedRoom, 'BBB:A1');
      expect(session.isJoined, true);

      ptt.dispose();
    });

    test('PTT active unmutes and signals start; idle re-mutes and signals end',
        () async {
      final ptt = PTTService(recorder: FakeRecorder());
      final transport = FakeVoiceTransport();
      final signaling = FakeSignaling();
      final session =
          RideSession(ptt: ptt, transport: transport, signaling: signaling);
      await session.join('BBB:A1');
      await drain();

      ptt.manualPress();
      expect(transport.lastMuted, false);
      expect(signaling.startPttCount, 1);

      ptt.manualRelease();
      expect(transport.lastMuted, true);
      expect(signaling.endPttCount, 1);

      ptt.dispose();
    });

    test('connects to peers once a roster arrives', () async {
      final ptt = PTTService(recorder: FakeRecorder());
      final transport = FakeVoiceTransport();
      final signaling = FakeSignaling();
      final session =
          RideSession(ptt: ptt, transport: transport, signaling: signaling);
      await session.join('BBB:A1');
      await drain();
      expect(transport.connectToAllPeersCount, 0);

      signaling.setPeerCount(1); // server delivered a peer
      expect(transport.connectToAllPeersCount, 1);

      ptt.dispose();
    });

    test('leave stops gating and tears everything down', () async {
      final ptt = PTTService(recorder: FakeRecorder());
      final transport = FakeVoiceTransport();
      final signaling = FakeSignaling();
      final session =
          RideSession(ptt: ptt, transport: transport, signaling: signaling);
      await session.join('BBB:A1');
      await drain();

      await session.leave();

      expect(signaling.leftRoom, true);
      expect(transport.closeCount, 1);
      expect(transport.disposeStreamCount, 1);
      expect(signaling.disconnected, true);
      expect(session.isJoined, false);

      // After leaving, PTT changes must NOT transmit.
      final startsBefore = signaling.startPttCount;
      ptt.manualPress();
      expect(signaling.startPttCount, startsBefore);

      ptt.dispose();
    });
  });
}
