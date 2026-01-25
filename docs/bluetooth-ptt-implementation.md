# Bluetooth Headset Push-to-Talk Implementation

## Overview

This document describes the implementation of Bluetooth headset button capture for Push-to-Talk (PTT) functionality in the Peloton Communicator app, including solutions for preventing voice assistant activation on long-press.

## The Challenge

**Problem**: Long-pressing the Bluetooth headset play/pause button triggers the system voice assistant:
- **Android**: Google Assistant
- **iOS**: Siri

This interferes with the intended PTT functionality and creates a poor user experience.

## Solution Implementation

### Android Implementation

We've implemented a multi-layered approach to intercept media button events before the system voice assistant:

#### 1. Activity-Level Key Event Interception

**File**: `packages/mobile/android/app/src/main/kotlin/com/example/app/MainActivity.kt`

```kotlin
override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    // Intercept HEADSETHOOK and MEDIA_PLAY_PAUSE for PTT functionality
    when (event.keyCode) {
        KeyEvent.KEYCODE_HEADSETHOOK,
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        KeyEvent.KEYCODE_MEDIA_PLAY,
        KeyEvent.KEYCODE_MEDIA_PAUSE -> {
            // Detect long press via repeatCount
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount > 0) {
                // Consume the event to prevent voice assistant
                return true
            }

            handleKeyEventForPTT(event)
            return true  // Consume to prevent further propagation
        }
    }
    return super.dispatchKeyEvent(event)
}
```

**Key Points**:
- `dispatchKeyEvent()` is called **before** system-level handlers
- We detect long-press by checking `event.repeatCount > 0`
- Consuming the event (`return true`) prevents voice assistant activation
- Works for both single and long presses

#### 2. MediaSessionCompat Setup

We maintain the MediaSession approach for broader compatibility:

```kotlin
private fun setupMediaSession() {
    mediaSession = MediaSessionCompat(this, "PelotonPTT")
    mediaSession.setFlags(
        MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
        MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
    )
    // ... additional setup
}
```

#### 3. Permissions

**File**: `packages/mobile/android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### iOS Implementation

**File**: `packages/mobile/ios/Runner/AppDelegate.swift`

#### Limitations on iOS

**Important**: iOS has strict system-level restrictions:
- Apps **cannot** intercept long-press for Siri
- Long-press is handled at the CoreAudio/Bluetooth stack level
- `MPRemoteCommandCenter` only receives events that aren't consumed by system
- There is **no API** to override Siri activation on long-press

#### What We Can Do

```swift
private func setupRemoteCommandCenter(channel: FlutterMethodChannel) {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Enable commands we want to handle
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true

    commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
        self?.handlePTTButtonEvent(channel: channel)
        return .success
    }
}
```

**iOS Workaround**:
- Use **toggle mode** with single-press only
- Educate users to avoid long-press on iOS
- Consider using double-press or other gestures

## PTT Modes

### Toggle Mode (Recommended for iOS)

```dart
PTTMode.toggle
```

**Behavior**:
- **Single press**: Start recording
- **Another single press**: Stop recording
- **Long press**: Consumed on Android, triggers Siri on iOS

**Best for**: iOS users, hands-free operation with simple gestures

### Hold Mode (Best for Android)

```dart
PTTMode.hold
```

**Behavior**:
- **Press and hold**: Recording while button is held
- **Release**: Stop recording immediately
- **Long press**: Prevented on Android, triggers Siri on iOS

**Best for**: Android users, traditional walkie-talkie feel

## Testing

### Android Testing

1. **Build and deploy** to physical Android device (emulators don't support Bluetooth headsets properly)
   ```bash
   cd packages/mobile
   flutter run --release
   ```

2. **Connect Bluetooth headset** to the device

3. **Test scenarios**:
   - Single press → Should toggle/activate PTT
   - Long press (>500ms) → Should be consumed, NOT trigger Google Assistant
   - Rapid presses → Should be debounced (300ms interval)

4. **Check logs**:
   ```bash
   adb logcat | grep PTT
   ```

### iOS Testing

1. **Build and deploy** to physical iOS device
   ```bash
   cd packages/mobile
   flutter run --release
   ```

2. **Connect Bluetooth headset** to the device

3. **Test scenarios**:
   - Single press → Should toggle PTT
   - Long press → Will trigger Siri (expected limitation)
   - Use toggle mode exclusively

4. **Check logs** in Xcode console

## Known Limitations

### Android
- ✅ **Long-press voice assistant**: Prevented via `dispatchKeyEvent()`
- ✅ **Single and double press**: Fully supported
- ✅ **Both PTT modes**: Toggle and Hold work well
- ⚠️ **Manufacturer differences**: Some OEMs may have custom Bluetooth stacks

### iOS
- ❌ **Long-press voice assistant**: Cannot be prevented (iOS restriction)
- ✅ **Single press**: Works well in toggle mode
- ⚠️ **Hold mode**: Not recommended due to Siri activation risk
- ⚠️ **App must be foreground**: iOS restricts background media button handling

## User Recommendations

### For Android Users
1. Use either **Toggle** or **Hold** mode based on preference
2. Both modes work reliably
3. Long-press is intercepted and won't trigger Google Assistant

### For iOS Users
1. Use **Toggle mode only**
2. Use quick single presses (avoid holding the button)
3. Be aware that long-press will trigger Siri
4. Keep app in foreground during rides
5. Consider using on-screen button as alternative

## Alternative Solutions Considered

### 1. Foreground Service (Android)
**Status**: Not implemented yet
- Could provide even higher priority for button capture
- Useful for background operation
- May be needed for production

### 2. Accessibility Service (Android)
**Status**: Rejected
- Requires extensive permissions
- Poor UX (users must enable in settings)
- Overkill for this use case

### 3. Custom Bluetooth Profile
**Status**: Not feasible
- Would require custom headset firmware
- Not compatible with standard headsets

### 4. Siri Shortcuts (iOS)
**Status**: Under consideration
- Could create "PTT" shortcut
- Still requires long-press, just redirects to app
- Doesn't solve the core problem

## Future Improvements

1. **Foreground Service** for Android background operation
2. **Alternative gestures**: Double-press, triple-press patterns
3. **Haptic feedback** on button press confirmation
4. **Volume button PTT** as fallback option
5. **Wearable integration**: Apple Watch, WearOS for alternative input

## References

### Android Documentation
- [MediaSession](https://developer.android.com/reference/android/media/session/MediaSession)
- [Handling Media Buttons](https://developer.android.com/guide/topics/media-apps/mediabuttons)
- [dispatchKeyEvent](https://developer.android.com/reference/android/app/Activity#dispatchKeyEvent(android.view.KeyEvent))

### iOS Documentation
- [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter)
- [AVAudioSession](https://developer.apple.com/documentation/avfoundation/avaudiosession)
- [Becoming a Now Playable App](https://developer.apple.com/documentation/mediaplayer/becoming_a_now_playable_app)

## Support

For issues or questions:
1. Check device logs (see Testing section)
2. Verify Bluetooth headset compatibility
3. Test on different Android versions (10+)
4. Test on different iOS versions (14+)

---

**Last Updated**: 2025-10-06
**Platforms**: Android 10+, iOS 14+
**Status**: Beta - Ready for device testing
