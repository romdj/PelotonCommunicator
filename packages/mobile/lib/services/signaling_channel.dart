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
