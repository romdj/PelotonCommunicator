import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_client.dart';
import 'voice_transport.dart';

/// Connection state for a peer connection
enum PeerConnectionState {
  new_,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// Configuration for WebRTC connections
class WebRTCConfig {
  final List<Map<String, dynamic>> iceServers;
  final bool audioOnly;

  const WebRTCConfig({
    this.iceServers = const [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    this.audioOnly = true,
  });

  Map<String, dynamic> toConfiguration() => {
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      };
}

/// Represents a WebRTC peer connection with another user
class PeerConnection {
  final String peerId;
  final String sessionId;
  final RTCPeerConnection connection;
  final List<RTCIceCandidate> pendingCandidates = [];
  PeerConnectionState state = PeerConnectionState.new_;
  MediaStream? remoteStream;

  PeerConnection({
    required this.peerId,
    required this.sessionId,
    required this.connection,
  });
}

/// WebRTC service for managing peer connections and audio streams
class WebRTCService extends ChangeNotifier implements VoiceTransport {
  final SignalingClient _signaling;
  final WebRTCConfig _config;

  MediaStream? _localStream;
  final Map<String, PeerConnection> _peerConnections = {};
  bool _isMuted = false;

  // Callbacks
  Function(String peerId, MediaStream stream)? onRemoteStream;
  Function(String peerId)? onPeerDisconnected;

  WebRTCService({
    required SignalingClient signaling,
    WebRTCConfig config = const WebRTCConfig(),
  })  : _signaling = signaling,
        _config = config {
    _setupSignalingCallbacks();
  }

  MediaStream? get localStream => _localStream;
  bool get isMuted => _isMuted;
  List<String> get connectedPeerIds => _peerConnections.keys.toList();

  void _setupSignalingCallbacks() {
    _signaling.onOffer = _handleOffer;
    _signaling.onAnswer = _handleAnswer;
    _signaling.onCandidate = _handleCandidate;
    _signaling.onPeerJoined = _handlePeerJoined;
    _signaling.onPeerLeft = _handlePeerLeft;
  }

  /// Initialize the local audio stream
  Future<void> initializeLocalStream() async {
    if (_localStream != null) return;

    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      debugPrint('Local audio stream initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to get local stream: $e');
      rethrow;
    }
  }

  /// Dispose of the local audio stream
  Future<void> disposeLocalStream() async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
      notifyListeners();
    }
  }

  /// Toggle mute state
  void toggleMute() {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
      notifyListeners();
    }
  }

  /// Set mute state
  void setMuted(bool muted) {
    if (_localStream != null && _isMuted != muted) {
      _isMuted = muted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
      notifyListeners();
    }
  }

  /// Connect to all peers in the room
  Future<void> connectToAllPeers() async {
    for (final peer in _signaling.peers) {
      await _createOfferForPeer(peer.id);
    }
  }

  /// Create a peer connection and send an offer
  Future<void> _createOfferForPeer(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      debugPrint('Already connected to peer: $peerId');
      return;
    }

    final sessionId = generateSessionId(_signaling.userId, peerId);
    final pc = await _createPeerConnection(peerId, sessionId);

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.connection.addTrack(track, _localStream!);
      }
    }

    // Create and send offer
    final offer = await pc.connection.createOffer();
    await pc.connection.setLocalDescription(offer);

    _signaling.sendOffer(
      peerId,
      sessionId,
      RTCSessionDescriptionData(type: offer.type!, sdp: offer.sdp!),
    );

    debugPrint('Sent offer to peer: $peerId');
  }

  /// Handle incoming offer
  Future<void> _handleOffer(String peerId, RTCSessionDescriptionData description) async {
    debugPrint('Received offer from: $peerId');

    final sessionId = generateSessionId(_signaling.userId, peerId);

    // Get or create peer connection
    PeerConnection pc;
    if (_peerConnections.containsKey(peerId)) {
      pc = _peerConnections[peerId]!;
    } else {
      pc = await _createPeerConnection(peerId, sessionId);

      // Add local tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await pc.connection.addTrack(track, _localStream!);
        }
      }
    }

    // Set remote description
    await pc.connection.setRemoteDescription(
      RTCSessionDescription(description.sdp, description.type),
    );

    // Add any pending candidates
    for (final candidate in pc.pendingCandidates) {
      await pc.connection.addCandidate(candidate);
    }
    pc.pendingCandidates.clear();

    // Create and send answer
    final answer = await pc.connection.createAnswer();
    await pc.connection.setLocalDescription(answer);

    _signaling.sendAnswer(
      peerId,
      sessionId,
      RTCSessionDescriptionData(type: answer.type!, sdp: answer.sdp!),
    );

    debugPrint('Sent answer to peer: $peerId');
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(String peerId, RTCSessionDescriptionData description) async {
    debugPrint('Received answer from: $peerId');

    final pc = _peerConnections[peerId];
    if (pc == null) {
      debugPrint('No peer connection for: $peerId');
      return;
    }

    await pc.connection.setRemoteDescription(
      RTCSessionDescription(description.sdp, description.type),
    );

    // Add any pending candidates
    for (final candidate in pc.pendingCandidates) {
      await pc.connection.addCandidate(candidate);
    }
    pc.pendingCandidates.clear();
  }

  /// Handle incoming ICE candidate
  Future<void> _handleCandidate(String peerId, RTCIceCandidateData candidateData) async {
    debugPrint('Received ICE candidate from: $peerId');

    final pc = _peerConnections[peerId];
    final candidate = RTCIceCandidate(
      candidateData.candidate,
      candidateData.sdpMid,
      candidateData.sdpMLineIndex,
    );

    if (pc == null) {
      // Store for later if we don't have a connection yet
      debugPrint('Storing candidate for later: $peerId');
      return;
    }

    if (pc.connection.signalingState == RTCSignalingState.RTCSignalingStateStable ||
        pc.connection.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
        pc.connection.signalingState == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
      try {
        await pc.connection.addCandidate(candidate);
      } catch (e) {
        debugPrint('Failed to add candidate: $e');
        pc.pendingCandidates.add(candidate);
      }
    } else {
      pc.pendingCandidates.add(candidate);
    }
  }

  /// Handle peer joined event
  void _handlePeerJoined(Peer peer) {
    debugPrint('Peer joined: ${peer.id}');
    // Initiate connection to the new peer
    _createOfferForPeer(peer.id);
  }

  /// Handle peer left event
  void _handlePeerLeft(String peerId) {
    debugPrint('Peer left: $peerId');
    _closePeerConnection(peerId);
  }

  /// Create a new peer connection
  Future<PeerConnection> _createPeerConnection(String peerId, String sessionId) async {
    final connection = await createPeerConnection(_config.toConfiguration());

    final pc = PeerConnection(
      peerId: peerId,
      sessionId: sessionId,
      connection: connection,
    );

    // Handle ICE candidates
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _signaling.sendCandidate(
          peerId,
          sessionId,
          RTCIceCandidateData(
            candidate: candidate.candidate!,
            sdpMid: candidate.sdpMid!,
            sdpMLineIndex: candidate.sdpMLineIndex!,
          ),
        );
      }
    };

    // Handle connection state changes
    connection.onConnectionState = (state) {
      debugPrint('Connection state for $peerId: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          pc.state = PeerConnectionState.connecting;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          pc.state = PeerConnectionState.connected;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          pc.state = PeerConnectionState.disconnected;
          onPeerDisconnected?.call(peerId);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          pc.state = PeerConnectionState.failed;
          onPeerDisconnected?.call(peerId);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          pc.state = PeerConnectionState.closed;
          break;
        default:
          break;
      }
      notifyListeners();
    };

    // Handle remote tracks
    connection.onTrack = (event) {
      debugPrint('Received track from $peerId: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        pc.remoteStream = event.streams[0];
        onRemoteStream?.call(peerId, event.streams[0]);
        notifyListeners();
      }
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  /// Close a peer connection
  Future<void> _closePeerConnection(String peerId) async {
    final pc = _peerConnections.remove(peerId);
    if (pc != null) {
      await pc.connection.close();
      pc.remoteStream?.dispose();
      onPeerDisconnected?.call(peerId);
      notifyListeners();
    }
  }

  /// Close all peer connections
  Future<void> closeAllConnections() async {
    for (final peerId in _peerConnections.keys.toList()) {
      await _closePeerConnection(peerId);
    }
  }

  /// Get the connection state for a peer
  PeerConnectionState? getPeerState(String peerId) {
    return _peerConnections[peerId]?.state;
  }

  /// Get the remote stream for a peer
  MediaStream? getRemoteStream(String peerId) {
    return _peerConnections[peerId]?.remoteStream;
  }

  @override
  void dispose() {
    closeAllConnections();
    disposeLocalStream();
    super.dispose();
  }
}
