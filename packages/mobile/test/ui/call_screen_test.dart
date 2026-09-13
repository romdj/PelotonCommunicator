import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/services/ptt_service.dart';
import 'package:app/ui/screens/call_screen.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('CallScreen joins the room muted on init and leaves on dispose',
      (tester) async {
    final transport = FakeVoiceTransport();
    final signaling = FakeSignaling();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<PTTService>(
        create: (_) => PTTService(recorder: FakeRecorder()),
        child: CallScreen(
          serverUrl: 'ws://localhost:8080',
          roomId: 'BBB:A1',
          transport: transport,
          signaling: signaling,
        ),
      ),
    ));
    await tester.pump(); // let initState's async join settle
    await tester.pump(const Duration(milliseconds: 10));

    expect(signaling.joinedRoom, 'BBB:A1');
    expect(transport.lastMuted, true);

    // Replace the screen to trigger dispose -> RideSession.leave().
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(signaling.leftRoom, true);
    expect(signaling.disconnected, true);
  });
}
