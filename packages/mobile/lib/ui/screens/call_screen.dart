import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ptt_state.dart';
import '../../services/ptt_service.dart';
import '../../services/signaling_client.dart';
import '../../services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String serverUrl;
  final String roomId;

  const CallScreen({
    super.key,
    required this.serverUrl,
    this.roomId = 'default',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late SignalingClient _signaling;
  late WebRTCService _webrtc;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Create signaling client
      _signaling = SignalingClient(
        serverUrl: widget.serverUrl,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        deviceInfo: Theme.of(context).platform.name,
      );

      // Create WebRTC service
      _webrtc = WebRTCService(signaling: _signaling);

      // Set up callbacks
      _webrtc.onRemoteStream = (peerId, stream) {
        debugPrint('Remote stream from $peerId');
        setState(() {});
      };

      _webrtc.onPeerDisconnected = (peerId) {
        debugPrint('Peer disconnected: $peerId');
        setState(() {});
      };

      // Connect to signaling server
      await _signaling.connect();

      // Initialize local audio
      await _webrtc.initializeLocalStream();

      // Join room
      _signaling.joinRoom(widget.roomId);

      // Listen for signaling state changes
      _signaling.addListener(_onSignalingUpdate);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  void _onSignalingUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _signaling.removeListener(_onSignalingUpdate);
    _webrtc.dispose();
    _signaling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Room: ${widget.roomId}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getConnectionColor(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getConnectionText(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildError();
    }

    if (!_isInitialized) {
      return _buildLoading();
    }

    return Column(
      children: [
        // Peers list
        Expanded(child: _buildPeersList()),

        // PTT controls
        _buildPTTControls(),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.deepOrange),
          SizedBox(height: 16),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isInitialized = false;
                });
                _initializeServices();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeersList() {
    final peers = _signaling.peers;

    if (peers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for others to join...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share room code: ${widget.roomId}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        final isTalking = _signaling.isPeerTalking(peer.id);
        final connectionState = _webrtc.getPeerState(peer.id);

        return Card(
          color: Colors.grey[850],
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: isTalking ? Colors.green : Colors.grey[700],
                  child: Icon(
                    isTalking ? Icons.mic : Icons.person,
                    color: Colors.white,
                  ),
                ),
                if (isTalking)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              peer.userId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              peer.deviceInfo ?? 'Unknown device',
              style: TextStyle(color: Colors.grey[500]),
            ),
            trailing: _buildConnectionBadge(connectionState),
          ),
        );
      },
    );
  }

  Widget _buildConnectionBadge(PeerConnectionState? state) {
    Color color;
    String text;

    switch (state) {
      case PeerConnectionState.connected:
        color = Colors.green;
        text = 'Connected';
        break;
      case PeerConnectionState.connecting:
        color = Colors.orange;
        text = 'Connecting';
        break;
      case PeerConnectionState.disconnected:
      case PeerConnectionState.failed:
        color = Colors.red;
        text = 'Disconnected';
        break;
      default:
        color = Colors.grey;
        text = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildPTTControls() {
    return Consumer<PTTService>(
      builder: (context, pttService, child) {
        final isActive = pttService.state.isActive;

        // Sync PTT state with signaling
        if (isActive) {
          _signaling.startPTT();
          _webrtc.setMuted(false);
        } else {
          _signaling.endPTT();
          _webrtc.setMuted(true);
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PTT Button
                GestureDetector(
                  onTapDown: pttService.button == PTTButton.onScreen &&
                          pttService.mode.isToggle
                      ? (_) => pttService.manualPress()
                      : null,
                  onLongPressStart: pttService.button == PTTButton.onScreen &&
                          pttService.mode.isHold
                      ? (_) => pttService.manualPress()
                      : null,
                  onLongPressEnd: pttService.button == PTTButton.onScreen &&
                          pttService.mode.isHold
                      ? (_) => pttService.manualRelease()
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: isActive ? 100 : 80,
                    height: isActive ? 100 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.green : Colors.deepOrange,
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? Colors.green : Colors.deepOrange)
                              .withOpacity(0.4),
                          blurRadius: isActive ? 30 : 15,
                          spreadRadius: isActive ? 5 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isActive ? Icons.mic : Icons.mic_none,
                      size: isActive ? 50 : 40,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status text
                Text(
                  isActive ? 'TRANSMITTING' : 'PUSH TO TALK',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                // Mode indicator
                Text(
                  pttService.button == PTTButton.onScreen
                      ? (pttService.mode.isToggle ? 'Tap to toggle' : 'Hold to talk')
                      : 'Using ${pttService.button.displayName}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getConnectionColor() {
    if (!_isInitialized) return Colors.grey;

    switch (_signaling.connectionState) {
      case SignalingConnectionState.connected:
        return Colors.green;
      case SignalingConnectionState.connecting:
        return Colors.orange;
      case SignalingConnectionState.error:
        return Colors.red;
      case SignalingConnectionState.disconnected:
        return Colors.grey;
    }
  }

  String _getConnectionText() {
    if (!_isInitialized) return 'Initializing';

    switch (_signaling.connectionState) {
      case SignalingConnectionState.connected:
        return 'Connected';
      case SignalingConnectionState.connecting:
        return 'Connecting';
      case SignalingConnectionState.error:
        return 'Error';
      case SignalingConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
