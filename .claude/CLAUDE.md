# Peloton Communicator Project

## Overview
A **walkie-talkie style communication app** for people riding (Peloton) bikes together. Push-to-talk (PTT) is triggered by Bluetooth headset buttons, phone hardware buttons, an on-screen button, or the iOS system PTT UI, and voice is streamed to other riders over WebRTC.

## Status (July 2026)

**The historic "major blocker" — capturing Bluetooth headset button events — is solved.** Do not re-investigate it from scratch; see `docs/bluetooth-ptt-implementation.md` for the working architecture and `ROADMAP.md` for what remains.

- **Android**: A Media3 `MediaSessionService` foreground service (`PttMediaSessionService.kt`) owns the media session and intercepts BT play/pause/headsethook key events, even when the app is backgrounded or the screen is off. Events flow `PttEventBus` → `MainActivity` → MethodChannel → `ptt_service.dart`. Volume buttons are captured in the activity (`onKeyDown`/`onKeyUp`).
- **iOS**: Apple's **PushToTalk framework** (iOS 16+, `PTTSystemManager.swift`) provides system PTT UI, background transmit, and headset button events via `setAccessoryButtonEventsEnabled(true)`. This framework (released 2022) is the official platform unlock — use it, don't fight MPRemoteCommandCenter.
- **WebRTC**: Signaling service (Go, `packages/services/signaling`), Flutter signaling client, and WebRTC service are implemented. PTT→WebRTC integration and NAT traversal (STUN/TURN) are the current MVP focus.

### Known Bluetooth protocol constraints (not bugs — do not try to "fix" in-app)
1. **Hold-to-talk on BT play/pause is unreliable.** Most headset firmware buffers the button to disambiguate single/double/long presses, so the AVRCP command arrives as a press+release pair at physical release; Android may also suppress `ACTION_UP` for BT devices. The app therefore **forces toggle mode for the play/pause button** — keep that behavior.
2. **Headset volume buttons don't generate KeyEvents.** With AVRCP absolute volume, the headset sends `SET_ABSOLUTE_VOLUME` straight to the audio system. Implemented workaround: `PttPlayer` claims remote device volume (Media3's `VolumeProvider` equivalent) while the volume button is selected, and routes steps through `PttEventBus.emitDiscrete()` — toggle mode only, never hold.
3. True press-and-hold with reliable down/up is achievable with **dedicated BLE PTT buttons** (handlebar-mountable; the Zello/ESChat ecosystem) — a candidate premium path.

## Repository Structure (monorepo)
```
├── packages/
│   ├── mobile/              # Flutter app (iOS/Android)
│   │   ├── lib/services/    # ptt_service, recorder_service, WebRTC, signaling client
│   │   ├── android/…/app/   # MainActivity, PttMediaSessionService, PttEventBus, PttPlayer
│   │   └── ios/Runner/      # AppDelegate, PTTSystemManager (PushToTalk framework)
│   ├── server/              # Go backend API server (legacy)
│   ├── services/signaling/  # WebRTC signaling service (Go, WebSocket)
│   └── infra/               # docker-compose, k3s manifests
├── docs/                    # bluetooth-ptt-implementation.md and others
├── ROADMAP.md               # Current diagnosis + next steps
└── scripts/                 # Build and deployment scripts
```

## Communication Flow
1. Button press (headset / hardware / on-screen / iOS system PTT) → `pttPressed` over MethodChannel
2. `ptt_service.dart` drives state; recorder starts (POC) — target: unmute WebRTC audio track
3. Release/toggle → `pttReleased` → stop transmitting

## Development Guidelines

### Testing
- Flutter: `flutter test` in `packages/mobile`
- Signaling (Go): `go test -race ./...` (unit) and `go test -race -tags=integration ./cmd/...` (real WebSocket flows) in `packages/services/signaling`
- `packages/server` is legacy (placeholder only) and is not in CI
- Follow TDD practices where applicable

### CI and local gates
- Single pipeline: `.github/workflows/ci.yml` (quality → build & unit → integration → security → `CI Status`). Details and local repro commands: `docs/ci-pipeline.md`
- `CI Status` is the required check on `main`; add new jobs to its `needs:` list to make them merge-blocking
- Toolchain pins live in the workflow `env:` (Flutter 3.47.1, Go 1.27.x, Java 17); keep the signaling Dockerfile's Go version in sync
- Local hooks via lefthook (`brew install lefthook && lefthook install`): format + analyze/vet on commit, tests on push. Never use `--no-verify`
- Analyzer runs with `--fatal-infos`: infos (deprecations, missing `const`) fail the build
- **Headset behavior requires physical devices** (emulators insufficient); expect per-headset AVRCP variance
- Testing guides: `TESTING.md`, `PHASE*_TESTING.md`, `WIRELESS_DEBUG_SETUP.md`

### Code Organization
- Keep Flutter UI components modular and reusable; PTT state management lives in `ptt_service.dart` (Provider)
- All press/release paths converge on one state transition so input sources are indistinguishable downstream
- Follow Go best practices for package organization

## Development Environment
- **Java**: 21 (Gradle 8.7+, AGP 8.4+); Android SDK 36, Kotlin 2.1
- **Flutter**: >= 3.16.0 · **Go**: >= 1.21
- **Target Platforms**: Android 12+, iOS 16+ (PushToTalk framework floor)
- iOS PushToTalk requires the `com.apple.developer.push-to-talk` entitlement and a real device

## Common Commands
- Mobile: `cd packages/mobile && flutter run` / `flutter test` / `flutter clean && flutter pub get`
- Signaling: `cd packages/services/signaling && go run ./cmd/main.go` (ws://localhost:8080/ws, GET /health)
- Infra: `docker compose -f packages/infra/docker-compose.yaml up`, k3s manifests in `packages/infra/k3s/`
