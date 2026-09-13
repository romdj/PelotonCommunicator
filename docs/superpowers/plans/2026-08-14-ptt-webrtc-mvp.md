# PTT → WebRTC 2-Device Walkie-Talkie MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire push-to-talk to a live WebRTC connection so two riders in the same club-BBB group hear each other in real time, replacing the local loopback recorder with mic mute-gating.

**Architecture:** Introduce one coordinator, `RideSession`, that keeps a persistent WebRTC connection up (mic muted by default) and toggles the local audio track on `PTTService` state changes. A tiny club/group model maps the 7 fixed groups to isolated signaling rooms. A group-picker screen replaces the ad-hoc join dialog. The existing `WebRTCService`/`SignalingClient` are reused behind two narrow interfaces so `RideSession` is unit-testable without the platform.

**Tech Stack:** Flutter (Dart), `flutter_webrtc`, `web_socket_channel`, `provider`; Go signaling server (unchanged this milestone); `flutter_test` with hand-written fakes (no mockito).

## Global Constraints

- Flutter SDK >= 3.16.0; Dart null-safety.
- Mobile package lives in `packages/mobile`; Dart package name is `app` (imports use `package:app/...`).
- Tests use `flutter_test` only — **no** mockito/mocktail; fakes are hand-written classes.
- State management is `provider` (`ChangeNotifierProvider<PTTService>` at app root, single instance).
- Walkie-talkie invariant: the local mic track is **muted by default** whenever connected; PTT only unmutes.
- Overlap is allowed (no one-talker lock). Group selection is **not** persisted across launches.
- Room-id convention: `"<clubId>:<groupId>"`, e.g. `"BBB:A1"`.
- Do not delete `RecorderService` or its PTT wiring — it remains an optional self-test path.
- Run all commands from `packages/mobile`. Test command: `flutter test`. Analyze: `flutter analyze`.
- Commit after every task. Commit messages: no AI attribution/co-author trailers.

---

## File Structure

**New files:**
- `lib/models/riding_group.dart` — `RidingGroup`, `Club`, `roomIdFor`, `bbbClub` constant.
- `lib/services/voice_transport.dart` — `VoiceTransport` interface (implemented by `WebRTCService`).
- `lib/services/signaling_channel.dart` — `SignalingChannel` interface (implemented by `SignalingClient`).
- `lib/services/ride_session.dart` — the coordinator.
- `lib/ui/screens/group_picker_screen.dart` — 7-group picker + server URL.
- `test/models/riding_group_test.dart`
- `test/support/fakes.dart` — shared fakes (`FakeVoiceTransport`, `FakeSignaling`, `FakeRecorder`).
- `test/services/ride_session_test.dart`
- `test/ui/group_picker_screen_test.dart`
- `test/ui/call_screen_test.dart`

**Modified files:**
- `lib/services/webrtc_service.dart` — add `implements VoiceTransport`.
- `lib/services/signaling_client.dart` — add `implements SignalingChannel` + `peerCount` getter.
- `lib/ui/screens/call_screen.dart` — delegate transmit to `RideSession`; remove build-time PTT side-effect; accept optional injected `transport`/`signaling` for testing.
- `lib/ui/screens/home_screen.dart` — the join action navigates to `GroupPickerScreen`.

---

### Task 1: Club/group model

**Files:**
- Create: `lib/models/riding_group.dart`
- Test: `test/models/riding_group_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class RidingGroup { final String id; final String name; const RidingGroup({required this.id, required this.name}); }`
  - `class Club { final String id; final String name; final List<RidingGroup> groups; const Club({...}); String roomIdFor(RidingGroup group); }`
  - `const Club bbbClub` with 7 groups: `A1, A2, A3, A4, B1, B2, B3`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/riding_group_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/riding_group.dart';

void main() {
  group('bbbClub', () {
    test('has club id BBB and exactly 7 groups A1..A4, B1..B3', () {
      expect(bbbClub.id, 'BBB');
      expect(bbbClub.groups.map((g) => g.id).toList(),
          ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3']);
    });

    test('roomIdFor builds "<clubId>:<groupId>"', () {
      final a1 = bbbClub.groups.first;
      expect(bbbClub.roomIdFor(a1), 'BBB:A1');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/riding_group_test.dart`
Expected: FAIL — `Error: Not found: 'package:app/models/riding_group.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/models/riding_group.dart

/// A riding group within a club — the unit that maps 1:1 to a WebRTC room.
class RidingGroup {
  final String id;
  final String name;
  const RidingGroup({required this.id, required this.name});
}

/// A club that owns a fixed set of riding groups.
class Club {
  final String id;
  final String name;
  final List<RidingGroup> groups;
  const Club({required this.id, required this.name, required this.groups});

  /// Room id for [group], e.g. 'BBB:A1'. Distinct groups => isolated rooms.
  String roomIdFor(RidingGroup group) => '$id:${group.id}';
}

/// The single MVP club: BBB with 7 fixed groups.
const Club bbbClub = Club(
  id: 'BBB',
  name: 'BBB',
  groups: [
    RidingGroup(id: 'A1', name: 'A1'),
    RidingGroup(id: 'A2', name: 'A2'),
    RidingGroup(id: 'A3', name: 'A3'),
    RidingGroup(id: 'A4', name: 'A4'),
    RidingGroup(id: 'B1', name: 'B1'),
    RidingGroup(id: 'B2', name: 'B2'),
    RidingGroup(id: 'B3', name: 'B3'),
  ],
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/riding_group_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/riding_group.dart test/models/riding_group_test.dart
git commit -m "feat(mobile): add club BBB / 7-group model with room-id mapping"
```

---

### Task 2: Transport + signaling interfaces

Extract the two narrow interfaces `RideSession` depends on, and declare the existing concrete services as implementers. This is what lets Task 3 be tested without WebRTC/WebSocket platform code.

**Files:**
- Create: `lib/services/voice_transport.dart`
- Create: `lib/services/signaling_channel.dart`
- Modify: `lib/services/webrtc_service.dart` (class declaration + import)
- Modify: `lib/services/signaling_client.dart` (class declaration + import + `peerCount`)
- Test: `test/services/ride_session_test.dart` (interface-satisfaction smoke test only in this task; expanded in Task 3)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `abstract class VoiceTransport { Future<void> initializeLocalStream(); void setMuted(bool muted); Future<void> connectToAllPeers(); Future<void> closeAllConnections(); Future<void> disposeLocalStream(); }`
  - `abstract class SignalingChannel implements Listenable { Future<void> connect(); void joinRoom(String roomId); void leaveRoom(); void startPTT(); void endPTT(); Future<void> disconnect(); int get peerCount; }`
  - `WebRTCService implements VoiceTransport`
  - `SignalingClient implements SignalingChannel` with `int get peerCount => _peers.length;`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/ride_session_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/ride_session_test.dart`
Expected: FAIL — `Error: Not found: 'package:app/services/voice_transport.dart'`.

- [ ] **Step 3: Write the interfaces**

```dart
// lib/services/voice_transport.dart

/// Minimal transport surface RideSession needs to bring up, gate, and route
/// audio. Implemented by WebRTCService; faked in tests.
abstract class VoiceTransport {
  Future<void> initializeLocalStream();
  void setMuted(bool muted);
  Future<void> connectToAllPeers();
  Future<void> closeAllConnections();
  Future<void> disposeLocalStream();
}
```

```dart
// lib/services/signaling_channel.dart
import 'package:flutter/foundation.dart';

/// Minimal signaling surface RideSession needs. Implemented by SignalingClient
/// (a ChangeNotifier, hence Listenable); faked in tests.
abstract class SignalingChannel implements Listenable {
  Future<void> connect();
  void joinRoom(String roomId);
  void leaveRoom();
  void startPTT();
  void endPTT();
  Future<void> disconnect();

  /// Number of peers currently known in the joined room.
  int get peerCount;
}
```

- [ ] **Step 4: Declare the concrete implementers**

In `lib/services/webrtc_service.dart`, add the import near the other imports:

```dart
import 'voice_transport.dart';
```

Change the class declaration from:

```dart
class WebRTCService extends ChangeNotifier {
```

to:

```dart
class WebRTCService extends ChangeNotifier implements VoiceTransport {
```

In `lib/services/signaling_client.dart`, add the import near the top:

```dart
import 'signaling_channel.dart';
```

Change the class declaration from:

```dart
class SignalingClient extends ChangeNotifier {
```

to:

```dart
class SignalingClient extends ChangeNotifier implements SignalingChannel {
```

Then add this getter inside `SignalingClient` (next to the other getters such as `List<Peer> get peers => ...`):

```dart
  @override
  int get peerCount => _peers.length;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/ride_session_test.dart`
Expected: PASS (1 test). If the compiler reports a missing member on either service, the interface and the concrete class have drifted — align the signature, do not weaken the interface.

- [ ] **Step 6: Commit**

```bash
git add lib/services/voice_transport.dart lib/services/signaling_channel.dart \
        lib/services/webrtc_service.dart lib/services/signaling_client.dart \
        test/services/ride_session_test.dart
git commit -m "refactor(mobile): extract VoiceTransport and SignalingChannel interfaces"
```

---

### Task 3: RideSession coordinator

**Files:**
- Create: `lib/services/ride_session.dart`
- Create: `test/support/fakes.dart`
- Modify: `test/services/ride_session_test.dart` (add behavior tests alongside the Task 2 smoke test)

**Interfaces:**
- Consumes: `VoiceTransport`, `SignalingChannel` (Task 2); `PTTService` and `PTTStateExtension.isActive` from `lib/services/ptt_service.dart` / `lib/models/ptt_state.dart`; `RecorderService` (for the fake).
- Produces:
  - `class RideSession { RideSession({required PTTService ptt, required VoiceTransport transport, required SignalingChannel signaling}); bool get isJoined; Future<void> join(String roomId); Future<void> leave(); }`
  - `test/support/fakes.dart` exporting `FakeVoiceTransport`, `FakeSignaling`, `FakeRecorder`.

- [ ] **Step 1: Write the shared fakes**

```dart
// test/support/fakes.dart
import 'package:flutter/foundation.dart';
import 'package:app/services/voice_transport.dart';
import 'package:app/services/signaling_channel.dart';
import 'package:app/services/recorder_service.dart';

class FakeVoiceTransport implements VoiceTransport {
  final List<bool> muteHistory = [];
  int initCount = 0;
  int connectToAllPeersCount = 0;
  int closeCount = 0;
  int disposeStreamCount = 0;

  bool? get lastMuted => muteHistory.isEmpty ? null : muteHistory.last;

  @override
  Future<void> initializeLocalStream() async => initCount++;
  @override
  void setMuted(bool muted) => muteHistory.add(muted);
  @override
  Future<void> connectToAllPeers() async => connectToAllPeersCount++;
  @override
  Future<void> closeAllConnections() async => closeCount++;
  @override
  Future<void> disposeLocalStream() async => disposeStreamCount++;
}

class FakeSignaling extends ChangeNotifier implements SignalingChannel {
  int connectCount = 0;
  String? joinedRoom;
  bool leftRoom = false;
  bool disconnected = false;
  int startPttCount = 0;
  int endPttCount = 0;
  int _peerCount = 0;

  @override
  int get peerCount => _peerCount;

  /// Simulate the server delivering a peer roster.
  void setPeerCount(int value) {
    _peerCount = value;
    notifyListeners();
  }

  @override
  Future<void> connect() async => connectCount++;
  @override
  void joinRoom(String roomId) => joinedRoom = roomId;
  @override
  void leaveRoom() => leftRoom = true;
  @override
  void startPTT() => startPttCount++;
  @override
  void endPTT() => endPttCount++;
  @override
  Future<void> disconnect() async => disconnected = true;
}

class FakeRecorder implements RecorderService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopAndPlayback() async {}
  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 2: Write the failing behavior tests**

Append to `test/services/ride_session_test.dart` (keep the existing Task 2 smoke test and its imports; add these imports and this `group`):

```dart
import 'package:flutter/services.dart';
import 'package:app/models/ptt_state.dart';
import 'package:app/services/ptt_service.dart';
import 'package:app/services/ride_session.dart';
import '../support/fakes.dart';

// Inside main(), add:
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
    final session = RideSession(ptt: ptt, transport: transport, signaling: signaling);

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
    final session = RideSession(ptt: ptt, transport: transport, signaling: signaling);
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
    final session = RideSession(ptt: ptt, transport: transport, signaling: signaling);
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
    final session = RideSession(ptt: ptt, transport: transport, signaling: signaling);
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/services/ride_session_test.dart`
Expected: FAIL — `Error: Not found: 'package:app/services/ride_session.dart'`.

- [ ] **Step 4: Write the implementation**

```dart
// lib/services/ride_session.dart
import '../models/ptt_state.dart';
import 'ptt_service.dart';
import 'voice_transport.dart';
import 'signaling_channel.dart';

/// Coordinates the three PTT subsystems into a live walkie-talkie session:
/// keeps a persistent, muted WebRTC connection and gates the mic on PTT state.
///
/// Walkie-talkie invariant: the local mic track is muted whenever joined;
/// holding PTT is the only thing that unmutes it.
class RideSession {
  final PTTService _ptt;
  final VoiceTransport _transport;
  final SignalingChannel _signaling;

  bool _joined = false;
  bool get isJoined => _joined;

  RideSession({
    required PTTService ptt,
    required VoiceTransport transport,
    required SignalingChannel signaling,
  })  : _ptt = ptt,
        _transport = transport,
        _signaling = signaling;

  /// Connect, come up MUTED, join [roomId], and start gating the mic on PTT.
  Future<void> join(String roomId) async {
    if (_joined) return;
    await _signaling.connect();
    await _transport.initializeLocalStream();
    _transport.setMuted(true); // silent until PTT is held
    _signaling.joinRoom(roomId);
    _signaling.addListener(_onSignalingChanged);
    _ptt.addListener(_onPttChanged);
    _joined = true;
  }

  void _onSignalingChanged() {
    // Offer to any peers already in the room when the roster arrives.
    // connectToAllPeers is idempotent per peer, so repeat calls are safe.
    if (_signaling.peerCount > 0) {
      _transport.connectToAllPeers();
    }
  }

  void _onPttChanged() {
    if (_ptt.state.isActive) {
      _transport.setMuted(false);
      _signaling.startPTT();
    } else {
      _transport.setMuted(true);
      _signaling.endPTT();
    }
  }

  /// Stop gating, leave the room, and tear down the connection.
  Future<void> leave() async {
    if (!_joined) return;
    _ptt.removeListener(_onPttChanged);
    _signaling.removeListener(_onSignalingChanged);
    _signaling.leaveRoom();
    await _transport.closeAllConnections();
    await _transport.disposeLocalStream();
    await _signaling.disconnect();
    _joined = false;
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/ride_session_test.dart`
Expected: PASS (Task 2 smoke test + 4 behavior tests = 5).

- [ ] **Step 6: Commit**

```bash
git add lib/services/ride_session.dart test/support/fakes.dart \
        test/services/ride_session_test.dart
git commit -m "feat(mobile): add RideSession coordinating PTT, WebRTC mute, signaling"
```

---

### Task 4: Group picker screen

**Files:**
- Create: `lib/ui/screens/group_picker_screen.dart`
- Test: `test/ui/group_picker_screen_test.dart`

**Interfaces:**
- Consumes: `bbbClub`, `RidingGroup`, `Club.roomIdFor` (Task 1); `CallScreen` (existing, unchanged signature `CallScreen({required String serverUrl, String roomId})`).
- Produces:
  - `class GroupPickerScreen extends StatefulWidget { final void Function(BuildContext context, String serverUrl, String roomId)? onSelect; const GroupPickerScreen({super.key, this.onSelect}); }`
  - Each group button carries `Key('group_<id>')`, e.g. `Key('group_A1')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/group_picker_screen_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/group_picker_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:app/ui/screens/group_picker_screen.dart'`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/screens/group_picker_screen.dart
import 'package:flutter/material.dart';
import '../../models/riding_group.dart';
import 'call_screen.dart';

/// Lets a rider pick one of club BBB's 7 groups and a signaling server URL,
/// then hands the resulting room id to [onSelect]. When [onSelect] is null it
/// opens the CallScreen for that room. Selection is not persisted.
class GroupPickerScreen extends StatefulWidget {
  final void Function(BuildContext context, String serverUrl, String roomId)?
      onSelect;

  const GroupPickerScreen({super.key, this.onSelect});

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:8080');

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  void _select(RidingGroup group) {
    final roomId = bbbClub.roomIdFor(group);
    final serverUrl = _serverController.text;
    (widget.onSelect ?? _openCallScreen)(context, serverUrl, roomId);
  }

  void _openCallScreen(BuildContext context, String serverUrl, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(serverUrl: serverUrl, roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('Club ${bbbClub.name} — pick a group')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _serverController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Server URL',
                labelStyle: TextStyle(color: Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final group in bbbClub.groups)
                    ElevatedButton(
                      key: Key('group_${group.id}'),
                      onPressed: () => _select(group),
                      child: Text(
                        group.name,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/group_picker_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/screens/group_picker_screen.dart test/ui/group_picker_screen_test.dart
git commit -m "feat(mobile): add club BBB group picker screen"
```

---

### Task 5: Wire CallScreen to RideSession + route from HomeScreen

Delete the build-time PTT side-effect in `CallScreen` and delegate transmit to `RideSession`. Add optional injected `transport`/`signaling` so the screen is testable with fakes. Point the home screen's call action at the group picker.

**Files:**
- Modify: `lib/ui/screens/call_screen.dart`
- Modify: `lib/ui/screens/home_screen.dart`
- Test: `test/ui/call_screen_test.dart`

**Interfaces:**
- Consumes: `RideSession` (Task 3); `VoiceTransport`/`SignalingChannel` (Task 2); `GroupPickerScreen` (Task 4); `PTTService` from provider; fakes from `test/support/fakes.dart`.
- Produces: `CallScreen` now accepts optional `VoiceTransport? transport` and `SignalingChannel? signaling` in addition to the existing `serverUrl`/`roomId`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/call_screen_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/call_screen_test.dart`
Expected: FAIL — compile error: `CallScreen` has no named parameter `transport`.

- [ ] **Step 3: Update imports and constructor in `call_screen.dart`**

Add these imports after the existing service imports at the top of `lib/ui/screens/call_screen.dart`:

```dart
import '../../services/voice_transport.dart';
import '../../services/signaling_channel.dart';
import '../../services/ride_session.dart';
```

Replace the widget field/constructor block (currently lines ~9-16) with:

```dart
  final String serverUrl;
  final String roomId;

  /// Injected for tests; production builds create real services internally.
  final VoiceTransport? transport;
  final SignalingChannel? signaling;

  const CallScreen({
    super.key,
    required this.serverUrl,
    this.roomId = 'default',
    this.transport,
    this.signaling,
  });
```

- [ ] **Step 4: Replace the service-init logic and PTT wiring in `_CallScreenState`**

Change the state fields (currently `late SignalingClient _signaling; late WebRTCService _webrtc;`) to:

```dart
  late final SignalingChannel _signaling;
  late final VoiceTransport _transport;
  RideSession? _session;
  bool _isInitialized = false;
  String? _errorMessage;
```

Replace `_initializeServices()` with:

```dart
  Future<void> _initializeServices() async {
    try {
      if (widget.transport != null && widget.signaling != null) {
        _signaling = widget.signaling!;
        _transport = widget.transport!;
      } else {
        final client = SignalingClient(
          serverUrl: widget.serverUrl,
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
          deviceInfo: Theme.of(context).platform.name,
        );
        _signaling = client;
        _transport = WebRTCService(signaling: client);
      }

      // Rebuild the peer list as signaling state changes.
      _signaling.addListener(_onSignalingUpdate);

      _session = RideSession(
        ptt: context.read<PTTService>(),
        transport: _transport,
        signaling: _signaling,
      );
      await _session!.join(widget.roomId);

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize: $e');
    }
  }
```

Replace `dispose()` with:

```dart
  @override
  void dispose() {
    _signaling.removeListener(_onSignalingUpdate);
    _session?.leave();
    super.dispose();
  }
```

- [ ] **Step 5: Remove the build-time PTT side-effect and make the peer list type-safe**

In `_buildPTTControls`, delete these lines from the `Consumer<PTTService>` builder (they are now owned by `RideSession`):

```dart
        // Sync PTT state with signaling
        if (isActive) {
          _signaling.startPTT();
          _webrtc.setMuted(false);
        } else {
          _signaling.endPTT();
          _webrtc.setMuted(true);
        }
```

The builder keeps using `final isActive = pttService.state.isActive;` for rendering only.

In `_buildPeersList`, replace the first line `final peers = _signaling.peers;` with a type-guarded read (the interface does not expose the peer list):

```dart
    final peers =
        _signaling is SignalingClient ? (_signaling as SignalingClient).peers : const <Peer>[];
```

And replace `final connectionState = _webrtc.getPeerState(peer.id);` with:

```dart
    final connectionState = _transport is WebRTCService
        ? (_transport as WebRTCService).getPeerState(peer.id)
        : null;
```

`_getConnectionColor`/`_getConnectionText` already call `_signaling.connectionState`; since the interface omits it, guard them too — replace `_signaling.connectionState` in both with:

```dart
    final state = _signaling is SignalingClient
        ? (_signaling as SignalingClient).connectionState
        : SignalingConnectionState.connected;
```

and switch on `state`. (`Peer`, `SignalingConnectionState`, and `PeerConnectionState` are already imported via `signaling_client.dart`/`webrtc_service.dart`.)

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/ui/call_screen_test.dart`
Expected: PASS (1 test). Then run `flutter analyze` and confirm no new errors.

- [ ] **Step 7: Route HomeScreen to the group picker**

In `lib/ui/screens/home_screen.dart`, add the import:

```dart
import 'group_picker_screen.dart';
```

Delete the entire `_showJoinRoomDialog` method, and change the call `IconButton`'s `onPressed` (currently `() => _showJoinRoomDialog(context)`) to:

```dart
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupPickerScreen()),
            ),
```

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: PASS — all suites (existing `ptt_service_test.dart`, `widget_test.dart`, plus the four new suites). Then `flutter analyze` clean.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/screens/call_screen.dart lib/ui/screens/home_screen.dart \
        test/ui/call_screen_test.dart
git commit -m "feat(mobile): drive CallScreen transmit through RideSession, route via group picker"
```

---

## Manual verification (Milestone A — two physical devices)

Not automatable; run once the tasks are green.

1. On your laptop: `cd packages/services/signaling && go run ./cmd/main.go` (listens on `:8080`). Note the laptop's LAN IP (e.g. `192.168.1.20`).
2. Build/run the app on **two physical phones** on the **same WiFi**: `cd packages/mobile && flutter run`.
3. On both phones: tap the call action → GroupPickerScreen → set Server URL to `ws://<laptop-ip>:8080` → tap the **same** group (e.g. `A1`).
4. Confirm each phone shows the other in the peer list as `Connected`.
5. Hold PTT on phone 1 → phone 2 hears live audio; release → audio stops. Repeat phone 2 → phone 1.
6. Negative check: put phone 2 in group `B1` instead → the two must **not** hear each other.

Expected result: bidirectional live audio for same-group phones on LAN; isolation across groups. This satisfies the spec's success criterion for Milestone A. TURN/cellular is Milestone B (separate plan).

## Self-Review

- **Spec coverage:** transmit model (mute-gating) → Tasks 2/3/5; `RideSession` coordinator → Task 3; default-muted invariant → Task 3 (`join`) + Task 5 test; group model BBB/7 → Task 1; room isolation → Task 1 + manual step 6; group picker, no persistence → Task 4; overlap allowed → no locking logic added (satisfied by omission); loopback retained as self-test → `RecorderService`/`PTTService` untouched; pre-existing-peer connect bug → Task 3 `_onSignalingChanged`; LAN/STUN test → manual section. TURN/cellular, SFU, auth/store, headset perfection, CI/CD → explicitly deferred, no tasks (correct).
- **Placeholders:** none — every code step contains complete code.
- **Type consistency:** `VoiceTransport`/`SignalingChannel` member names match `WebRTCService`/`SignalingClient` methods used in Task 3 and Task 5; `peerCount`, `roomIdFor`, `RideSession.join/leave/isJoined`, and the `Key('group_<id>')` convention are used consistently across tasks.
