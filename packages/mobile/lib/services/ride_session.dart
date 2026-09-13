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
