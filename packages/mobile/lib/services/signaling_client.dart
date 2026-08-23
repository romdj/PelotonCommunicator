import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'signaling_channel.dart';

/// Connection state for the signaling client
enum SignalingConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Represents a peer in the room
class Peer {
  final String id;
  final String userId;
  final String? deviceInfo;
  final int joinedAt;

  Peer({
    required this.id,
    required this.userId,
    this.deviceInfo,
    required this.joinedAt,
  });

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      id: json['id'] as String,
      userId: json['userId'] as String,
      deviceInfo: json['deviceInfo'] as String?,
      joinedAt: json['joinedAt'] as int? ?? 0,
    );
  }
}

/// WebRTC SDP description
class RTCSessionDescriptionData {
  final String type;
  final String sdp;

  RTCSessionDescriptionData({required this.type, required this.sdp});

  factory RTCSessionDescriptionData.fromJson(Map<String, dynamic> json) {
    return RTCSessionDescriptionData(
      type: json['type'] as String,
      sdp: json['sdp'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'sdp': sdp};
}

/// ICE candidate data
class RTCIceCandidateData {
  final String candidate;
  final String sdpMid;
  final int sdpMLineIndex;

  RTCIceCandidateData({
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
  });

  factory RTCIceCandidateData.fromJson(Map<String, dynamic> json) {
    return RTCIceCandidateData(
      candidate: json['candidate'] as String,
      sdpMid: json['sdpMid'] as String,
      sdpMLineIndex: json['sdpMLineIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      };
}

/// Signaling client for WebRTC peer coordination
class SignalingClient extends ChangeNotifier implements SignalingChannel {
  WebSocketChannel? _channel;
  final String _serverUrl;
  final String _userId;
  final String? _deviceInfo;

  SignalingConnectionState _connectionState = SignalingConnectionState.disconnected;
  String? _currentRoomId;
  final List<Peer> _peers = [];
  final Map<String, bool> _talkingPeers = {};

  // Callbacks for WebRTC events
  Function(String peerId, RTCSessionDescriptionData description)? onOffer;
  Function(String peerId, RTCSessionDescriptionData description)? onAnswer;
  Function(String peerId, RTCIceCandidateData candidate)? onCandidate;
  Function(Peer peer)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String peerId, bool isTalking)? onPeerTalking;
  Function(List<Peer> peers)? onPeersUpdated;
  Function(String code, String message)? onError;

  SignalingClient({
    required String serverUrl,
    required String userId,
    String? deviceInfo,
  })  : _serverUrl = serverUrl,
        _userId = userId,
        _deviceInfo = deviceInfo;

  SignalingConnectionState get connectionState => _connectionState;
  String? get currentRoomId => _currentRoomId;
  String get userId => _userId;
  List<Peer> get peers => List.unmodifiable(_peers);
  @override
  int get peerCount => _peers.length;
  bool isPeerTalking(String peerId) => _talkingPeers[peerId] ?? false;

  /// Connect to the signaling server
  Future<void> connect() async {
    if (_connectionState == SignalingConnectionState.connecting ||
        _connectionState == SignalingConnectionState.connected) {
      return;
    }

    _setConnectionState(SignalingConnectionState.connecting);

    try {
      final uri = Uri.parse('$_serverUrl/ws?userId=$_userId&deviceInfo=${Uri.encodeComponent(_deviceInfo ?? '')}');
      debugPrint('Connecting to signaling server: $uri');

      _channel = WebSocketChannel.connect(uri);

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _setConnectionState(SignalingConnectionState.error);
          onError?.call('connection_error', error.toString());
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _setConnectionState(SignalingConnectionState.disconnected);
          _currentRoomId = null;
          _peers.clear();
          _talkingPeers.clear();
        },
      );

      _setConnectionState(SignalingConnectionState.connected);
      debugPrint('Connected to signaling server');
    } catch (e) {
      debugPrint('Failed to connect to signaling server: $e');
      _setConnectionState(SignalingConnectionState.error);
      onError?.call('connection_failed', e.toString());
    }
  }

  /// Disconnect from the signaling server
  Future<void> disconnect() async {
    if (_currentRoomId != null) {
      leaveRoom();
    }
    await _channel?.sink.close();
    _channel = null;
    _setConnectionState(SignalingConnectionState.disconnected);
    _peers.clear();
    _talkingPeers.clear();
    notifyListeners();
  }

  /// Join a signaling room
  void joinRoom(String roomId) {
    _send('join_room', {
      'roomId': roomId,
      'userId': _userId,
      'deviceInfo': _deviceInfo,
    });
    _currentRoomId = roomId;
    notifyListeners();
  }

  /// Leave the current room
  void leaveRoom() {
    if (_currentRoomId != null) {
      _send('leave_room', {'roomId': _currentRoomId});
      _currentRoomId = null;
      _peers.clear();
      _talkingPeers.clear();
      notifyListeners();
    }
  }

  /// Send a WebRTC offer to a peer
  void sendOffer(String toPeerId, String sessionId, RTCSessionDescriptionData description) {
    _send('offer', {
      'to': toPeerId,
      'sessionId': sessionId,
      'description': description.toJson(),
    });
  }

  /// Send a WebRTC answer to a peer
  void sendAnswer(String toPeerId, String sessionId, RTCSessionDescriptionData description) {
    _send('answer', {
      'to': toPeerId,
      'sessionId': sessionId,
      'description': description.toJson(),
    });
  }

  /// Send an ICE candidate to a peer
  void sendCandidate(String toPeerId, String sessionId, RTCIceCandidateData candidate) {
    _send('candidate', {
      'to': toPeerId,
      'sessionId': sessionId,
      'candidate': candidate.toJson(),
    });
  }

  /// Signal that PTT is starting (user is talking)
  void startPTT() {
    _send('ptt_start', {'roomId': _currentRoomId});
  }

  /// Signal that PTT is ending (user stopped talking)
  void endPTT() {
    _send('ptt_end', {'roomId': _currentRoomId});
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel == null) {
      debugPrint('Cannot send message: not connected');
      return;
    }

    final message = jsonEncode({'type': type, 'data': data});
    debugPrint('Sending: $message');
    _channel!.sink.add(message);
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final type = decoded['type'] as String;
      final data = decoded['data'] as Map<String, dynamic>;

      debugPrint('Received message: $type');

      switch (type) {
        case 'peers':
          _handlePeers(data);
          break;
        case 'peer_joined':
          _handlePeerJoined(data);
          break;
        case 'peer_left':
          _handlePeerLeft(data);
          break;
        case 'offer':
          _handleOffer(data);
          break;
        case 'answer':
          _handleAnswer(data);
          break;
        case 'candidate':
          _handleCandidate(data);
          break;
        case 'peer_talking':
          _handlePeerTalking(data);
          break;
        case 'error':
          _handleError(data);
          break;
        default:
          debugPrint('Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  void _handlePeers(Map<String, dynamic> data) {
    final peersList = (data['peers'] as List).cast<Map<String, dynamic>>();
    _peers.clear();
    for (final peerJson in peersList) {
      _peers.add(Peer.fromJson(peerJson));
    }
    onPeersUpdated?.call(_peers);
    notifyListeners();
  }

  void _handlePeerJoined(Map<String, dynamic> data) {
    final peer = Peer.fromJson(data['peer'] as Map<String, dynamic>);
    _peers.add(peer);
    onPeerJoined?.call(peer);
    notifyListeners();
  }

  void _handlePeerLeft(Map<String, dynamic> data) {
    final peerId = data['peerId'] as String;
    _peers.removeWhere((p) => p.id == peerId);
    _talkingPeers.remove(peerId);
    onPeerLeft?.call(peerId);
    notifyListeners();
  }

  void _handleOffer(Map<String, dynamic> data) {
    final from = data['from'] as String;
    final description = RTCSessionDescriptionData.fromJson(
        data['description'] as Map<String, dynamic>);
    onOffer?.call(from, description);
  }

  void _handleAnswer(Map<String, dynamic> data) {
    final from = data['from'] as String;
    final description = RTCSessionDescriptionData.fromJson(
        data['description'] as Map<String, dynamic>);
    onAnswer?.call(from, description);
  }

  void _handleCandidate(Map<String, dynamic> data) {
    final from = data['from'] as String;
    final candidate = RTCIceCandidateData.fromJson(
        data['candidate'] as Map<String, dynamic>);
    onCandidate?.call(from, candidate);
  }

  void _handlePeerTalking(Map<String, dynamic> data) {
    final peerId = data['peerId'] as String;
    final isTalking = data['isTalking'] as bool;
    _talkingPeers[peerId] = isTalking;
    onPeerTalking?.call(peerId, isTalking);
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> data) {
    final code = data['code'] as String;
    final message = data['message'] as String;
    debugPrint('Server error: $code - $message');
    onError?.call(code, message);
  }

  void _setConnectionState(SignalingConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// Utility to generate session IDs
String generateSessionId(String peerId1, String peerId2) {
  // Sort to ensure consistent session IDs regardless of who initiates
  final ids = [peerId1, peerId2]..sort();
  return '${ids[0]}-${ids[1]}';
}
