/// Minimal transport surface RideSession needs to bring up, gate, and route
/// audio. Implemented by WebRTCService; faked in tests.
abstract class VoiceTransport {
  Future<void> initializeLocalStream();
  void setMuted(bool muted);
  Future<void> connectToAllPeers();
  Future<void> closeAllConnections();
  Future<void> disposeLocalStream();
}
