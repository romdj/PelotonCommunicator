import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/screens/group_picker_screen.dart';

void main() {
  testWidgets('tapping group A1 selects room BBB:A1', (tester) async {
    String? selectedRoom;
    String? selectedServer;

    await tester.pumpWidget(MaterialApp(
      home: GroupPickerScreen(
        onSelect: (context, serverUrl, roomId) {
          selectedServer = serverUrl;
          selectedRoom = roomId;
        },
      ),
    ));

    expect(find.byKey(const Key('group_A1')), findsOneWidget);
    expect(find.byKey(const Key('group_B3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_A1')));
    await tester.pump();

    expect(selectedRoom, 'BBB:A1');
    expect(selectedServer, 'ws://localhost:8080');
  });
}
