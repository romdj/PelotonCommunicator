# Roadmap

## Status: the headset-button blocker is solved

For a long time this project was stalled on "can we reliably capture Bluetooth headset
play/pause button presses for push-to-talk." As of the `feat/configurable-ptt-buttons`
branch, the answer is yes on both platforms:

- **Android**: `PttMediaSessionService.kt` is a Media3 `MediaSessionService` running as a
  foreground service. It owns the media session and receives BT play/pause/headsethook
  key events via `MediaSession.Callback.onMediaButtonEvent`, even when the app is
  backgrounded or the screen is off. Events go `PttEventBus` → `MainActivity` →
  MethodChannel → `ptt_service.dart`. Volume buttons are captured separately in the
  activity (`onKeyDown` / `onKeyUp`), since they aren't routed through MediaSession.
- **iOS**: `PTTSystemManager.swift` integrates Apple's **PushToTalk framework** (iOS 16+),
  which is the officially supported way to get background transmit and headset-button
  events (`setAccessoryButtonEventsEnabled(true)`). It's offered as the `systemPTT`
  button option alongside the existing `MPRemoteCommandCenter`-based handling in
  `AppDelegate.swift` (used for the `headsetPlayPause` / `headsetNext` / `headsetPrevious`
  options). Recommend `systemPTT` as the default headset option going forward — it gets
  background operation and proper accessory event routing that MPRemoteCommandCenter
  never had.

See `docs/bluetooth-ptt-implementation.md` for the full technical writeup.

## What's left — protocol limits, not missing code

These are Bluetooth/AVRCP protocol characteristics, confirmed against Android and Apple
documentation and how other PTT apps (Zello, ESChat) handle the same constraints. They
are not bugs to "fix" in application code:

1. **Hold-to-talk on headset play/pause is unreliable** (observed: button stayed "red"
   for ~950ms after release before flashing green). Most headset firmware buffers the
   button to disambiguate single/double/long press, so press+release arrive together at
   physical release; Android can also suppress `ACTION_UP` for BT devices entirely. The
   app already force-switches `playPause` to toggle mode (`ptt_service.dart:132-138`) —
   this is correct and matches industry practice. **No further action needed.**
2. **Headset volume up/down buttons aren't captured** (only the phone's physical volume
   keys are). With AVRCP absolute volume, the headset sends `SET_ABSOLUTE_VOLUME`
   directly to the audio system — no `KeyEvent` ever reaches the app.
3. **Phone button vs. headset button are distinguishable in code today** — both paths
   converge on `handleKeyEventForPTT`, so no UX difference; low-priority cleanup only.

## Next steps

### 1. Volume-button PTT via `VolumeProvider` (Android) — next up
Attach a [`VolumeProvider`](https://developer.android.com/reference/android/media/VolumeProvider)
to `PttMediaSessionService`'s media session to receive discrete headset volume up/down
callbacks. This unlocks **toggle-mode** PTT on headset volume buttons (not hold — AVRCP
only ever gives discrete steps, never down/up pairs).

- Owner: mobile/Android
- Files: `PttMediaSessionService.kt`, `PttPlayer.kt`
- Acceptance: pressing headset volume down/up while `PTTButton.volume` selected toggles
  PTT state; existing phone-hardware volume button path is unaffected.

### 2. Wire PTT state to WebRTC audio (currently POC-only)
`ptt_service.dart` currently drives `RecorderService` (local record + local playback).
The WebRTC signaling/service layer already exists (`signaling_client.dart`,
`webrtc_service.dart`, call screen). Replace the local-record POC path with: PTT press →
unmute/enable local audio track → WebRTC peer connection; PTT release → mute/disable
track. This is the core remaining MVP gap per `README.md`'s test matrix.

### 3. Default iOS headset button to `systemPTT`
Make `systemPTT` the recommended/default option for headset play/pause on iOS 16+, with
`headsetPlayPause` (MPRemoteCommandCenter) retained only as an iOS <16 fallback.

### 4. Config persistence
`PTTConfiguration` doesn't survive app restart yet (listed in
`PTT_IMPLEMENTATION_SUMMARY.md`). SharedPreferences (Android) / UserDefaults (iOS) via a
Flutter plugin (e.g. `shared_preferences`).

### 5. (Later / premium path) Dedicated BLE PTT buttons
For riders who want genuine press-and-hold, a handlebar-mounted BLE PTT button (the
Zello/ESChat hardware ecosystem) delivers reliable discrete down/up over BLE GATT,
sidestepping AVRCP entirely. Worth a spike once WebRTC audio is wired up and the MVP
test matrix in `README.md` is passing.
