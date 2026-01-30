# Peloton Communicator

A cross-platform push-to-talk communication system designed for group activities like cycling, running, and fitness sessions.

## Architecture

This is a monorepo containing multiple packages that work together to provide a complete communication solution:

```
├── packages/
│   ├── mobile/              # Flutter mobile app (iOS/Android)
│   ├── server/              # Go backend API server (legacy)
│   ├── services/
│   │   └── signaling/       # WebRTC signaling service (Go)
│   └── infra/               # Infrastructure configs
│       ├── docker-compose.yaml
│       └── k3s/             # Kubernetes manifests
├── docs/                    # Documentation
├── scripts/                 # Build and deployment scripts
└── .github/workflows/       # CI/CD pipelines
```

## MVP Status

**Goal**: Prove P2P voice connectivity works between phones over cellular networks.

### Test Matrix
- [ ] Android <-> Android (same WiFi)
- [ ] Android <-> Android (cellular)
- [ ] iOS <-> Android
- [ ] iOS <-> iOS
- [ ] Multicast scenarios (3+ devices)

### Components

| Component | Status | Description |
|-----------|--------|-------------|
| Signaling Service | Implemented | WebSocket server for WebRTC peer coordination |
| Flutter Signaling Client | Implemented | WebSocket client for room/peer management |
| Flutter WebRTC Service | Implemented | Peer connection and audio stream handling |
| PTT Integration | Pending | Connect PTT button events to WebRTC audio |
| NAT Traversal | Pending | STUN/TURN configuration for cellular networks |

## Quick Start

### Prerequisites
- **Flutter SDK** >= 3.16.0
- **Go** >= 1.21
- **Docker** (optional, for containerized development)

### Run Signaling Server (Local)

```bash
cd packages/services/signaling
go run ./cmd/main.go
```

The server starts on `http://localhost:8080` with these endpoints:
- `ws://localhost:8080/ws` - WebSocket signaling
- `GET /health` - Health check
- `GET /stats` - Connection statistics

### Run with Docker

```bash
cd packages/infra
docker-compose up
```

### Mobile App Development

```bash
cd packages/mobile
flutter pub get
flutter run
```

## Signaling Service

The signaling service handles WebRTC peer coordination via WebSocket.

### WebSocket Messages

| Type | Direction | Purpose |
|------|-----------|---------|
| `join_room` | Client -> Server | Join a signaling room |
| `leave_room` | Client -> Server | Leave current room |
| `peers` | Server -> Client | List of online peers |
| `peer_joined` | Server -> Client | New peer came online |
| `peer_left` | Server -> Client | Peer went offline |
| `offer` | Bidirectional | WebRTC SDP offer |
| `answer` | Bidirectional | WebRTC SDP answer |
| `candidate` | Bidirectional | ICE candidate |
| `ptt_start` | Client -> Server | Started transmitting |
| `ptt_end` | Client -> Server | Stopped transmitting |
| `peer_talking` | Server -> Client | Peer is transmitting |

### Connection Example (Dart)

```dart
import 'package:app/services/signaling_client.dart';
import 'package:app/services/webrtc_service.dart';

// Create signaling client
final signaling = SignalingClient(
  serverUrl: 'ws://localhost:8080',
  userId: 'user123',
  deviceInfo: 'Android',
);

// Create WebRTC service
final webrtc = WebRTCService(signaling: signaling);

// Connect and join room
await signaling.connect();
await webrtc.initializeLocalStream();
signaling.joinRoom('default');

// Handle remote audio
webrtc.onRemoteStream = (peerId, stream) {
  // Play remote audio
};
```

## Project Structure

### Signaling Service (`packages/services/signaling/`)

```
signaling/
├── cmd/main.go                    # Entry point
├── internal/
│   ├── config/config.go           # Configuration
│   └── websocket/
│       ├── hub.go                 # Room/connection management
│       ├── client.go              # WebSocket client handling
│       └── messages.go            # Message types
├── Dockerfile
├── go.mod
└── go.sum
```

### Flutter Services (`packages/mobile/lib/services/`)

```
services/
├── ptt_service.dart              # PTT button handling
├── signaling_client.dart         # WebSocket signaling
└── webrtc_service.dart           # WebRTC peer connections
```

## Features

### Mobile App
- **Push-to-Talk (PTT)** functionality with Bluetooth headset support
- **Dual PTT modes**: Toggle mode and Hold mode
- **Cross-platform**: iOS and Android support
- **WebRTC audio**: P2P voice communication
- **Modern UI** with state-aware visual feedback

### Signaling Service
- **WebSocket server** for real-time peer coordination
- **Room management** for group communications
- **Stateless design** ready for horizontal scaling
- **Health checks** for container orchestration

## Development

### Running Tests

```bash
# Mobile tests
cd packages/mobile && flutter test

# Signaling service tests
cd packages/services/signaling && go test ./...

# Integration tests
./scripts/test-all.sh
```

### Building for Production

```bash
# Build signaling service Docker image
cd packages/services/signaling
docker build -t peloton-signaling .

# Build mobile apps
cd packages/mobile
flutter build apk --release
flutter build ios --release
```

## Deployment

### Local Development (Docker Compose)

```bash
cd packages/infra
docker-compose up -d
```

### Kubernetes (k3s)

```bash
kubectl apply -f packages/infra/k3s/signaling-deployment.yaml
```

## Next Steps

1. **Create Call UI** - Build a screen that uses SignalingClient and WebRTCService
2. **Test Local Connectivity** - Verify Android <-> Android works on same WiFi
3. **Add TURN Server** - Configure coturn for NAT traversal
4. **Test Cellular** - Validate connectivity over mobile networks
5. **Integrate PTT** - Connect button events to WebRTC mute/unmute

## Known Limitations

- **iOS**: Long-press triggers Siri (iOS system restriction)
- **iOS Workaround**: Use toggle mode with single-press
- **Android**: Long-press voice assistant prevention implemented
- **NAT Traversal**: Direct P2P may fail without TURN server on cellular

## Documentation

- [Mobile App Documentation](./packages/mobile/README.md)
- [Signaling Service](./packages/services/signaling/)
- [Bluetooth PTT Implementation](./docs/bluetooth-ptt-implementation.md)
- [Testing Guide](./TESTING.md)
- [Architecture Overview](./docs/architecture.md)

## Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Development Standards
- **Code Style**: Follow language-specific style guides
- **Testing**: Maintain >80% test coverage
- **Documentation**: Update docs for all public APIs
- **Linting**: All code must pass linting checks

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with care for better group communication**
