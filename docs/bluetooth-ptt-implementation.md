# Bluetooth Headset Push-to-Talk Implementation

## Overview

This document describes how Bluetooth headset button capture works for Push-to-Talk
(PTT) in Peloton Communicator, and what is and isn't achievable given Bluetooth AVRCP
and platform media-button constraints. **This is no longer an open problem** — both
platforms reliably capture headset button presses. See `ROADMAP.md` for the remaining
work (headset volume buttons, WebRTC wiring).

## Android Implementation

### Foreground MediaSessionService

**File**: `packages/mobile/android/app/src/main/kotlin/com/example/app/PttMediaSessionService.kt`

A dedicated `MediaSessionService` (AndroidX Media3) owns the PTT media session and runs
as a foreground service, so it keeps receiving media button events even when the app is
backgrounded or the screen is off — this was the missing piece in earlier attempts that
only intercepted key events at the `Activity` level.

```kotlin
class PttMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val player = PttPlayer()
        mediaSession = MediaSession.Builder(this, player)
            .setId("PelotonPTT")
            .setCallback(PttSessionCallback())
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    private class PttSessionCallback : MediaSession.Callback {
        override fun onMediaButtonEvent(
            session: MediaSession,
            controllerInfo: MediaSession.ControllerInfo,
            intent: Intent
        ): Boolean {
            val key = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT) ?: return false
            return when (key.keyCode) {
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY,
                KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                    PttEventBus.emit(key)
                    true
                }
                else -> false
            }
        }
    }
}
```

`PttEventBus` (a simple in-process listener) forwards the raw `KeyEvent` to
`MainActivity`, which translates it into `pttPressed` / `pttReleased` MethodChannel
calls consumed by `ptt_service.dart`. `PttPlayer.kt` is a minimal `Player` stub the
`MediaSession` needs to exist and stay active.

`MainActivity.kt` starts this service (`startForegroundService`) once RECORD_AUDIO /
BLUETOOTH_CONNECT / (Android 13+) POST_NOTIFICATIONS permissions are granted, and keeps
`onKeyDown` / `onKeyUp` overrides for **volume buttons only** — those are activity-scoped
and are not delivered through `MediaSession.Callback`.

### Toggle vs. Hold mode

`handleKeyEventForPTT` in `MainActivity.kt` implements both modes with a 300ms
double-press debounce. Critically, **`ptt_service.dart` force-switches the play/pause
button to toggle mode** (`setButton()`), because hold mode is not reliable for that
button — see "Known AVRCP Limitations" below.

### Permissions

```xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

## iOS Implementation

Two paths exist side by side, selected per the `button` setting in `PTTConfiguration`:

### 1. `headsetPlayPause` / `headsetNext` / `headsetPrevious` — `MPRemoteCommandCenter`

**File**: `packages/mobile/ios/Runner/AppDelegate.swift` (`setupRemoteCommandCenter`)

Standard `MPRemoteCommandCenter` target registration. Works, but only while the app is
in the foreground, and — like every third-party iOS app — cannot intercept a long-press,
which the system routes to Siri before the app ever sees it. No API exists to change
this; it's a system-level restriction, not a bug in this codebase.

### 2. `systemPTT` — Apple's PushToTalk framework (iOS 16+, recommended)

**File**: `packages/mobile/ios/Runner/PTTSystemManager.swift`

Apple shipped the [PushToTalk framework](https://developer.apple.com/documentation/pushtotalk)
in iOS 16 specifically to give third-party apps proper headset-button PTT, including
**background** transmit. `ptt_service.dart` calls `joinPTTChannel` when this button is
selected; `PTTSystemManager` then:

```swift
manager.requestJoinChannel(channelUUID: uuid, descriptor: descriptor) { error in
    manager.setAccessoryButtonEventsEnabled(true, channelUUID: uuid) { err in ... }
}
```

`setAccessoryButtonEventsEnabled(true)` tells the system to map Bluetooth accessory
media events onto the PTT channel's `didBeginTransmittingFrom` / `didEndTransmittingFrom`
delegate callbacks, which `PTTSystemManager` forwards to Flutter as `pttPressed` /
`pttReleased`. This is the officially supported mechanism — prefer it over
`MPRemoteCommandCenter` wherever iOS 16+ can be assumed (requires the
`com.apple.developer.push-to-talk` entitlement; see `Runner.entitlements`).

Known quirk (from Apple's own developer forums): some A2DP head units send a "play"
event automatically on connect, which the framework will interpret as "begin
transmitting." This is inherent to how the framework maps generic media events onto PTT
semantics and isn't something the app can distinguish.

## Known AVRCP / Media-Button Limitations

These apply regardless of platform code quality — they're characteristics of Bluetooth
AVRCP and how OS media-button stacks work, confirmed against Android's own media3 issue
tracker and Apple's PushToTalk documentation:

1. **Long-press disambiguation swallows the release event.** Headset firmware buffers
   the button to tell single/double/long press apart, so the down+up pair is often only
   emitted once, at physical release — not at physical press. This is why holding the
   button appears to do nothing until you let go. **Mitigation**: use toggle mode for
   play/pause (already the default/forced behavior).
2. **Headset volume buttons don't emit `KeyEvent`s at all** once AVRCP absolute volume
   is negotiated (Android 6+) — the headset talks directly to the audio HAL via
   `SET_ABSOLUTE_VOLUME`. **Mitigation (planned, see `ROADMAP.md`)**: register a
   `VolumeProvider` on the media session to receive discrete volume-change callbacks;
   this supports toggle mode only, since AVRCP never delivers a true down/up pair for
   volume keys.
3. **True press-and-hold with a guaranteed down/up pair** requires bypassing AVRCP
   media-button semantics entirely — a dedicated BLE PTT button (GATT characteristic
   notifications, not AVRCP) as used by Zello/ESChat hardware accessories. Candidate for
   a future "premium hardware" path; see `ROADMAP.md`.

## Testing

**Physical devices required** — emulators do not support Bluetooth headset button
delivery. See `TESTING.md` and the `PHASE*_TESTING.md` guides for detailed scripts.

```bash
# Android
adb logcat | grep PTT

# iOS
# Xcode console; filter for "PTT"
```

## References

- [Android MediaSession](https://developer.android.com/reference/android/media/session/MediaSession)
- [Media3 MediaSessionService](https://developer.android.com/media/media3/session/background-playback)
- [androidx/media#159 — first BT pause press mishandled](https://github.com/androidx/media/issues/159)
- [Apple PushToTalk framework](https://developer.apple.com/documentation/PushToTalk)
- [Creating a Push to Talk app](https://developer.apple.com/documentation/pushtotalk/creating-a-push-to-talk-app)
- [WWDC22: Enhance voice communication with Push to Talk](https://developer.apple.com/videos/play/wwdc2022/10117/)
- [Android VolumeProvider](https://developer.android.com/reference/android/media/VolumeProvider)
- [AOSP AvrcpVolumeManager](https://android.googlesource.com/platform/packages/apps/Bluetooth/+/master/src/com/android/bluetooth/avrcp/AvrcpVolumeManager.java)

---

**Last Updated**: 2026-07-23
**Platforms**: Android 12+, iOS 16+ (for `systemPTT`; iOS 14+ for `MPRemoteCommandCenter` fallback)
**Status**: Headset button capture solved and in use; volume-button PTT and WebRTC wiring open (see `ROADMAP.md`)
