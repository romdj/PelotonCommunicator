Here’s a detailed recap of everything we’ve covered, organized by topic and chronological flow:

1. Project Kickoff & Core Requirements
Goal: Build a Flutter “Peloton Communicator” walkie-talkie POC that uses a Bluetooth headset’s play/pause button as a push-to-talk trigger.

Minimum Viable POC:

Press play → record microphone input.

Release pause → stop recording and immediately play back.

Platform Targets: Android 12+ and iOS 14+.

Architectural Emphasis:

Clear separation of UI (in lib/ui/) and logic/services (in lib/services/).

Up-to-date Flutter packages:

record for recording,

audioplayers for playback,

audio_service for media button handling.

2. Initial Setup & Dependencies
Project Creation:

bash
Copier
flutter create peloton_communicator
cd peloton_communicator
Pubspec Dependencies:

yaml
Copier
record: ^5.2.0
audioplayers: ^x.y.z
audio_service: ^x.y.z
provider: ^x.y.z (optional)
Directory Structure:

css
Copier
lib/
 ├ main.dart
 ├ services/
 │   ├ audio_controller.dart
 │   └ media_button_handler.dart
 └ ui/
     └ home_screen.dart
3. AudioController & Record Plugin Migration
Version Change: Upgraded from record 4.1.4 → 5.2.0.

API Shift: Record is now abstract with only static methods.

Naming Conflict: Dart 3 introduces built-in Record types, so we aliased the import (import 'package:record/record.dart' as rec;).

Final AudioController:

rec.Record.hasPermission()

rec.Record.start(...)

rec.Record.stop()

Playback via AudioPlayer.

4. Media Button Handling with audio_service
Custom Handler:

BaseAudioHandler subclass (MyAudioHandler) overrides play() to start recording and pause() to stop & play.

Initialization in main.dart:

dart
Copier
await AudioService.init(
  builder: () => myAudioHandler,
  config: AudioServiceConfig(
    androidNotificationChannelId: 'com.example.peloton_communicator',
    androidNotificationChannelName: 'Peloton Communicator Audio',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'ic_launcher',
  ),
);
5. Android Manifest & Permissions Troubleshooting
<uses-permission> Placement: Moved out of <application> into the root <manifest>.

Notification Icon Null Error: Added androidNotificationIcon: 'ic_launcher' so AudioService’s config strings are non-null.

Package Declaration: Ensured package="com.example.peloton_communicator" is on the <manifest> tag.

AudioService Service Registration: Added inside <application>:

xml
Copier
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:exported="false"
    android:foregroundServiceType="mediaPlayback"/>
6. FlutterEngine & AudioService Integration
Persistent Error: AudioService complaining that “Activity class … has not provided the correct FlutterEngine.”

Solution Path:

Custom Application Class (MyApplication) that:

Creates a FlutterEngine.

Executes the Dart entrypoint.

Caches it under FlutterEngineCache.DEFAULT_ENGINE_ID.

MainActivity Override of provideFlutterEngine(...) to return that cached engine.

AndroidManifest updated to android:name=".MyApplication".

Clean/Rebuild: flutter clean && flutter pub get && flutter run to apply.

7. Hardware Testing & Limitations
Android Emulator: Cannot simulate real Bluetooth media-button events—must use a physical Android device.

iOS Simulator: Also limited for Bluetooth testing; real iOS device (iPad/iPhone) needed.

iPad Pairing Issue:

“Unpaired” message in Xcode resolved by pairing in Window → Devices & Simulators, trusting the Mac, and ensuring correct signing in Xcode.

8. Dependency Management
Pub Commands:

flutter pub outdated → view outdated packages.

flutter pub upgrade → update within constraints.

flutter pub upgrade --major-versions → try major bumps (with manual pubspec.yaml edits as needed).

9. Long-Term Architecture Considerations
Hybrid P2P Architecture:

Centralized: Authentication, group management, signaling.

Decentralized: Direct device-to-device media streams (e.g. WebRTC/ICE/STUN, UDP, minimal TURN fallback).

Latency Optimization: UDP, Opus codec, jitter buffering, NAT traversal.

Security: End-to-end encryption (DTLS/SRTP), token-based auth.

Scalability: Mesh for small groups, selective forwarding or clustering for larger groups, dynamic relay fallbacks.

10. WhatsApp Call Architecture (Contextual Insight)
Central signaling servers for call setup.

Peer-to-peer media when possible (ICE/STUN, TURN fallback).

End-to-end encryption via the Signal Protocol.

Global, highly distributed infrastructure for low-latency signaling.

11. Upwork Project Description
Emphasis on:

Clean, modular, extensible POC structure.

Core push-to-talk via BT button.

Scoped POC deliverables & documentation for future phases.

Deliverables: Functional POC; documented code; architectural extension plan.

Next Steps / Outstanding Items

Finalize the Android native setup (ensure MyApplication + MainActivity + manifest are in sync).

Test on physical Android/iOS devices with real Bluetooth headsets.

Proceed to POC milestone: record/playback via BT button, then document extension path for P2P calling.

This summary consolidates all the technical decisions, troubleshooting steps, and architectural insights we’ve discussed—ready to share the full context with any stakeholder.






Demander à ChatGPT

