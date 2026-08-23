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
