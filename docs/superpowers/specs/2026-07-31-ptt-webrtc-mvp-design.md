# PTT → WebRTC 2-Device Walkie-Talkie MVP — Design

**Date:** 2026-07-31
**Status:** Approved for planning
**Branch:** `feat/ptt-webrtc-mvp` (stacked on `feat/configurable-ptt-buttons`)

## Goal / Success Criterion

Two phones (any mix of iOS/Android), each rider opens the app, picks a group in
club **BBB** (e.g. both pick `A1`), and when one **holds PTT** (on-screen button,
or iOS system PTT) the other **hears them live** — sub-second latency, both
directions. Proven first on the **same WiFi** (STUN only). Riders in group `A1`
do **not** hear riders in group `B2`.

This closes the one seam the codebase is missing: today PTT drives a **local
loopback recorder** (record → play back on the same device); the MVP makes PTT
**gate the microphone on a live WebRTC connection to another device**.

## Background: why this is a small change

Both halves already exist and are committed; they are simply not wired together:

| Piece | Status | Role |
|---|---|---|
| `SignalingClient` (`lib/services/signaling_client.dart`) | exists | WebSocket: join room, offer/answer/ICE, `startPTT`/`endPTT`, `peer_talking` |
| `WebRTCService` (`lib/services/webrtc_service.dart`) | exists | persistent peer connections, `setMuted()`, remote audio via `onRemoteStream` |
| `PTTService` (`lib/services/ptt_service.dart`) | exists | emits `active`/`idle` from native triggers (headset / iOS PTT / on-screen / manual) |
| Signaling server (`packages/services/signaling`, Go) | exists | room/peer hub |
| **`RideSession`** | **to build** | the glue that maps PTT state → WebRTC mute and owns call lifecycle |
| **Group model** | **to build** | club BBB + 7 groups → room id |

WebRTC was an established, sound protocol choice (real-time low-latency P2P
audio, built-in Opus + echo-cancel/noise-suppress/AGC, standard ICE/STUN/TURN,
cross-platform `flutter_webrtc`). The MVP continues that established direction —
README already lists "Integrate PTT → Connect button events to WebRTC
mute/unmute" as the next step.

## Architecture

### The new coordinator: `RideSession`

A single orchestrator (`lib/services/ride_session.dart` or `lib/controllers/`)
ties `PTTService`, `SignalingClient`, and `WebRTCService` together so no widget
has to know about all three. Responsibilities:

1. **Connect** the signaling client and **initialize the local mic stream muted**
   (`WebRTCService.initializeLocalStream()` then `setMuted(true)`).
2. **Join** the selected group's room (`signaling.joinRoom(roomId)`).
3. **Auto-connect** to peers (existing `connectToAllPeers` / `onPeerJoined`).
4. **Map PTT state to transmit:** listen to `PTTService`; on `active` →
   `webrtc.setMuted(false)` + `signaling.startPTT()`; on `idle` →
   `webrtc.setMuted(true)` + `signaling.endPTT()`.
5. **Surface** connection state, peer list, and who is talking (`peer_talking`)
   to the UI.
6. **Tear down** on leave/dispose (close peers, dispose local stream, leave room).

This **supersedes** the loopback wiring inside `PTTService._setState` (which
currently calls `_recorder.startRecording()` / `stopAndPlayback()`). The recorder
is **retained as an optional "self-test" mode**, not deleted — useful for
verifying mic capture without a peer.

### Data flow (the press path)

```
hold PTT → native → PTTService.active → RideSession
    → webrtc.setMuted(false) + signaling.startPTT()
    → peer receives live audio; peer UI shows "A1: <rider> talking"
release/toggle → PTTService.idle → RideSession
    → webrtc.setMuted(true) + signaling.endPTT()
```

The local mic track is **disabled by default** for the entire ride; PTT is
literally an unmute gate. Input source (headset / on-screen / iOS system PTT) is
indistinguishable downstream — all paths converge on `PTTService` state.

### Group model (minimal)

```
Club  { id: "BBB", name: "BBB", groups: [Group x7] }
Group { id, name }   // A1, A2, A3, A4, B1, B2, B3
```

- **Room id convention:** `"BBB:A1"` … `"BBB:B3"`. Client picks a group → joins
  that room. Groups in different rooms are fully isolated by the existing hub.
- **Membership** = live peers currently in the room. No persistence, no DB, no
  auth for the MVP.
- **Server change: near-zero** — the hub already isolates by room; groups are a
  client-side list plus a room-id convention. (Optionally the server validates
  the room id is one of the 7 known groups; not required for MVP.)
- **UI:** a simple group picker (7 buttons or a dropdown) shown before entering
  the call screen. Selection is **not persisted** — pick fresh each launch.

### Mute-gating semantics (walkie-talkie behavior)

- **Default:** local mic track disabled (muted) while connected.
- **Hold mode:** press = unmute, release = mute.
- **Toggle mode:** tap = unmute+lock, tap = mute. (Native already forces toggle
  semantics for the BT play/pause key; the settings UI hides hold mode when
  play/pause is selected.)
- **Overlap allowed (MVP decision):** if two riders in the same group hold PTT
  at once, both are heard. One-talker-at-a-time locking is out of scope; talking
  indicators (`peer_talking`) make concurrency visible.

### Trigger reliability tiers

- **Tier 1 — must work for the demo:** on-screen button (hold + toggle), iOS
  system PTT (PushToTalk framework).
- **Tier 2 — best-effort:** Android BT headset play/pause (toggle mode; AVRCP
  protocol limits documented in `docs/bluetooth-ptt-implementation.md`), volume
  buttons. Not blocking for MVP.

## Networking phases

- **Milestone A (this spec):** laptop signaling server on LAN, STUN only, both
  phones on the same WiFi. **Success = Android↔Android *and* iOS↔Android, both
  directions.**
- **Milestone B (next spec, out of scope here):** deploy signaling to k3s
  (config exists in `packages/infra/k3s`) + coturn TURN server → validate
  cellular / cross-network connectivity.

## Error handling

- **Signaling disconnect** → auto-reconnect + rejoin group room; UI reflects
  `SignalingConnectionState`.
- **Mic permission denied** → surface in UI, disable PTT (do not attempt
  transmit).
- **Peer connection failed** (`RTCPeerConnectionStateFailed`) →
  `onPeerDisconnected` → show dropped; attempt a single re-offer.
- **Empty group** → PTT still works (stays muted); no listeners, no error.
- **ICE candidate before remote description** → already handled via
  `pendingCandidates` buffering in `WebRTCService`.

## Testing strategy (TDD where it pays)

- **Unit (Dart):** `RideSession` maps PTT state → `setMuted`/`startPTT`/`endPTT`
  correctly (mock `WebRTCService` + `SignalingClient`); group → room-id logic;
  default-muted invariant on connect. Extends the existing
  `test/services/ptt_service_test.dart` patterns.
- **Widget:** group picker selects a room; PTT button drives `RideSession`;
  connection-state UI renders each `SignalingConnectionState`.
- **Go:** hub keeps rooms isolated (a peer in `BBB:A1` never receives traffic
  addressed to `BBB:B2`).
- **Manual E2E (the real proof):** two physical devices on the same WiFi against
  a laptop-hosted signaling server — cannot be emulated. Covers the README test
  matrix rows for same-WiFi.

## Explicitly out of scope (MVP)

- TURN / cellular connectivity (Milestone B).
- 3+ rider scaling / SFU (P2P mesh is fine for 2; revisit for groups).
- Auth, store, orders, and the full club/ride model from `documentation.yaml`.
- Android BT headset press/release perfection (AVRCP-limited; tracked, not
  blocking).
- The CI/CD pipeline (`cicd_plan.md`) — a separate track, not part of this spec.

## Open questions

None blocking. Milestone B (TURN/k3s) gets its own spec once Milestone A is
proven on two physical devices.
