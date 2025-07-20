# Peloton Communicator Project

## Overview
This project is a **walkie-talkie style communication app** for people riding Peloton bikes together. The core concept is to enable **push-to-talk (PTT) functionality using Bluetooth headset play/pause buttons** as triggers for voice communication between riders.

### Project Components
- A Flutter mobile app (`/app/`) for cross-platform client applications
- A Go backend server (`/server/`) using Gin framework with REST API
- Infrastructure configuration for AWS and GCP deployments (`/aws/`, `/gcp/`)
- WebRTC demo implementation (`/flutter-webrtc-demo/`)

### Core Innovation: Bluetooth Headset PTT
The **major technical challenge** and primary focus is capturing Bluetooth headset play/pause button events to trigger voice recording/transmission. This creates a hands-free communication experience essential for cycling.

## Architecture
- **Frontend**: Flutter app with Material Design
- **Backend**: Go server with Gin framework, RESTful API
- **API Documentation**: Swagger/OpenAPI specification in `documentation.yaml`
- **Infrastructure**: Terraform configurations for cloud deployment

## Key Components

### Flutter App (`/app/`)
- Main entry point: `lib/main.dart`
- Current state: Basic counter app template (needs development)
- Target platforms: iOS, Android, Web, Desktop (Linux, macOS, Windows)

### Go Server (`/server/`)
- Main file: `main.go` (currently a basic albums API example)
- Framework: Gin v1.7.2
- API specification: Based on `documentation.yaml` swagger spec
- Generated code: `server/generated/` contains auto-generated API handlers

### API Specification
- Swagger 2.0 specification in `documentation.yaml`
- Endpoints for:
  - Club management (CRUD operations)
  - User management and authentication
  - Store/order functionality
  - File upload capabilities

## Development Guidelines

### Testing
- Flutter: Use `flutter test` for unit and widget tests
- Go: Use `go test` for backend testing
- Follow TDD practices where applicable

### Code Organization
- Keep Flutter UI components modular and reusable
- Follow Go best practices for package organization
- Use existing patterns established in the codebase

### API Development
- Follow the OpenAPI specification in `documentation.yaml`
- Implement proper error handling and validation
- Use OAuth2 and API key authentication as specified

### Infrastructure
- Terraform configurations available for AWS and GCP
- Docker support through generated Dockerfile in server

## Technical Challenges & Solutions

### Bluetooth Headset Integration
**Problem**: Capturing Bluetooth headset play/pause button events for PTT functionality
**Current Status**: Major blocker - multiple approaches attempted

**Attempted Solutions**:
1. **audio_service Package**: MediaSession approach with custom handlers
2. **flutter_blue_plus**: BLE approach for modern Bluetooth devices
3. **Native Platform Channels**: Direct Android/iOS media button handling

**Key Learnings**:
- Requires physical device testing (emulators insufficient)
- Android: MediaSessionCompat + BroadcastReceiver for media button events
- iOS: MPRemoteCommandCenter for media button handling
- Build system compatibility: Java 21 + Gradle 8.7 + AGP 8.4+

### Current Architecture (POC)
```
Bluetooth Headset -> Platform Channel -> Flutter App -> Record Audio -> Playback
```

### Future Architecture (Full Implementation)
```
Bluetooth Headset -> PTT Trigger -> Record -> WebRTC/UDP -> Other Riders
```

## Communication Flow
1. **Press play button** → Start recording microphone
2. **Release button** → Stop recording, immediately playback locally (POC)
3. **Future**: Stream to other riders in real-time via WebRTC

## Project Structure
```
/app/                    # Flutter app (currently template)
  /lib/services/         # Audio controller, media button handler
  /lib/ui/              # UI components
/server/                # Go backend (currently example API)
/.claude/tmp/           # Previous implementation attempts/conversations
```

## Development Environment
- **Java**: 21 (requires Gradle 8.7+, AGP 8.4+)
- **Flutter**: Latest stable
- **Target Platforms**: Android 12+, iOS 14+
- **Testing**: Requires physical devices with Bluetooth headsets

## Common Commands
- Flutter: `flutter run`, `flutter build`, `flutter test`
- Go: `go run main.go`, `go build`, `go test`
- Infrastructure: `terraform plan`, `terraform apply`
- Clean build: `flutter clean && flutter pub get`