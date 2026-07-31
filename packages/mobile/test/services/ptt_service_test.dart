import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/ptt_state.dart';
import 'package:app/services/ptt_service.dart';
import 'package:app/services/recorder_service.dart';

class _FakeRecorderService implements RecorderService {
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  Future<void> startRecording() async {
    startCount++;
  }

  @override
  Future<void> stopAndPlayback() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.peloton/ptt');
  late List<MethodCall> nativeCalls;

  setUp(() {
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      nativeCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // Drain pending microtasks/Futures so fire-and-forget work (initial config
  // push, wakelock init, mode/button update calls) lands before assertions.
  Future<void> pumpEventQueue() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('PTTService initial state', () {
    test('starts in idle state with default configuration', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      expect(service.state, PTTState.idle);
      expect(service.mode, PTTMode.toggle);
      expect(service.button, PTTButton.volume);
      expect(service.config.preventScreenLock, isTrue);

      service.dispose();
    });

    test('pushes initial configuration to native on construction', () async {
      PTTService(recorder: _FakeRecorderService());
      await pumpEventQueue();

      final configCalls = nativeCalls
          .where((c) => c.method == 'updatePTTConfiguration')
          .toList();
      expect(configCalls, isNotEmpty,
          reason: 'expected initial config push to native');

      final args = configCalls.first.arguments as Map;
      expect(args['mode'], 'toggle');
      expect(args['button'], 'volume');
      expect(args['preventScreenLock'], true);
    });
  });

  group('native callback → state machine', () {
    test('pttPressed transitions to active and starts recording', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('pttPressed')),
        (_) {},
      );

      expect(service.state, PTTState.active);
      expect(recorder.startCount, 1);
      expect(recorder.stopCount, 0);

      service.dispose();
    });

    test('pttReleased transitions to idle and stops recording', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      // Drive to active first.
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('pttPressed')),
        (_) {},
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('pttReleased')),
        (_) {},
      );

      expect(service.state, PTTState.idle);
      expect(recorder.startCount, 1);
      expect(recorder.stopCount, 1);

      service.dispose();
    });

    test('idempotent state transitions do not double-fire recorder', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      // Two pttPressed calls in a row — recorder should only start once.
      for (var i = 0; i < 2; i++) {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('pttPressed')),
          (_) {},
        );
      }

      expect(service.state, PTTState.active);
      expect(recorder.startCount, 1);

      service.dispose();
    });
  });

  group('configuration updates', () {
    test('setMode updates mode and forwards to native', () async {
      final service = PTTService(recorder: _FakeRecorderService());
      await pumpEventQueue();
      nativeCalls.clear();

      service.setMode(PTTMode.hold);
      await pumpEventQueue();

      expect(service.mode, PTTMode.hold);
      final modeCalls = nativeCalls
          .where((c) => c.method == 'updatePTTConfiguration')
          .toList();
      expect(modeCalls, hasLength(1));
      expect((modeCalls.first.arguments as Map)['mode'], 'hold');

      service.dispose();
    });

    test('setButton(playPause) does NOT change mode (regression: native handles toggle semantics)',
        () async {
      final service = PTTService(recorder: _FakeRecorderService());
      await pumpEventQueue();
      // Set hold mode explicitly with the default (volume) button.
      service.setMode(PTTMode.hold);
      await pumpEventQueue();
      expect(service.mode, PTTMode.hold);

      // Switching to play/pause must NOT silently flip mode to toggle anymore.
      service.setButton(PTTButton.playPause);
      await pumpEventQueue();

      expect(service.button, PTTButton.playPause);
      expect(service.mode, PTTMode.hold,
          reason: 'mode should be preserved; native code forces toggle for play/pause keycodes');

      service.dispose();
    });

    test('setPreventScreenLock updates configuration', () async {
      final service = PTTService(recorder: _FakeRecorderService());
      await pumpEventQueue();

      service.setPreventScreenLock(false);
      await pumpEventQueue();

      expect(service.config.preventScreenLock, isFalse);

      service.dispose();
    });

    test('stops active recording when configuration changes', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      // Drive into active state.
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('pttPressed')),
        (_) {},
      );
      expect(service.state, PTTState.active);

      // Changing mode while active should drop us back to idle and stop recording.
      service.setMode(PTTMode.hold);
      await pumpEventQueue();

      expect(service.state, PTTState.idle);
      expect(recorder.stopCount, greaterThanOrEqualTo(1));

      service.dispose();
    });
  });

  group('lifecycle', () {
    test('dispose tears down recorder', () async {
      final recorder = _FakeRecorderService();
      final service = PTTService(recorder: recorder);
      await pumpEventQueue();

      service.dispose();

      expect(recorder.disposeCount, 1);
    });
  });
}
