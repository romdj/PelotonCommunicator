# Testing Guide: Bluetooth PTT Long-Press Fix

## What Changed

We've implemented a fix to prevent the voice assistant (Google Assistant/Siri) from launching when you long-press the Bluetooth headset button.

### Android Implementation ✅
- **Added**: `dispatchKeyEvent()` override in MainActivity.kt
- **Effect**: Intercepts media button events BEFORE system voice assistant
- **Result**: Long-press is consumed and won't trigger Google Assistant

### iOS Implementation ⚠️
- **Limitation**: iOS does not allow apps to override Siri long-press
- **Recommendation**: Use toggle mode with single-press only
- **Added**: Documentation comments explaining the limitation

## Quick Test Steps

### Prerequisites
- Physical Android or iOS device (Bluetooth doesn't work properly in emulators)
- Bluetooth headset/earbuds with media buttons
- Pair and connect the headset to your device

### Build and Deploy

```bash
cd packages/mobile

# For Android
flutter run --release

# For iOS
flutter run --release
```

### Test Scenarios

#### Android Testing

1. **Test 1: Single Press (Toggle Mode)**
   - Press the headset button once quickly
   - **Expected**: PTT should activate/deactivate
   - **Check**: UI should show recording state change

2. **Test 2: Long Press (Toggle Mode)**
   - Press and hold the headset button for 1+ seconds
   - **Expected**: PTT activates on initial press, Google Assistant should NOT launch
   - **Check**: No Google Assistant popup

3. **Test 3: Hold Mode**
   - Switch to Hold mode in the app
   - Press and hold the button
   - **Expected**: Recording while held, stops on release, no Google Assistant
   - **Check**: Recording follows press/release, no assistant

4. **Test 4: Rapid Presses**
   - Press the button multiple times quickly
   - **Expected**: Should be debounced (300ms interval)
   - **Check**: Only registers presses spaced 300ms+ apart

#### iOS Testing

1. **Test 1: Single Press (Toggle Mode)**
   - Press the headset button once quickly
   - **Expected**: PTT should activate/deactivate
   - **Check**: UI shows recording state

2. **Test 2: Long Press - Known Limitation**
   - Press and hold the headset button for 1+ seconds
   - **Expected**: Siri WILL launch (this is normal on iOS)
   - **Check**: This is expected behavior due to iOS restrictions

3. **Test 3: Quick Toggle Usage**
   - Use only quick single presses
   - **Expected**: Reliable toggle PTT without triggering Siri
   - **Check**: Works well when avoiding long presses

### Check Logs

#### Android
```bash
# Connect device via USB
adb logcat | grep PTT

# Look for these messages:
# "dispatchKeyEvent: keyCode=XXX, action=XXX"
# "Long press detected (repeat=X) - consuming to prevent voice assistant"
# "Starting recording (toggle/hold mode)"
# "Stopping recording (toggle/hold mode)"
```

#### iOS
```bash
# View in Xcode
# Open Xcode → Window → Devices and Simulators
# Select your device → View Device Logs
# Filter for: "PTT"

# Look for:
# "Toggle play/pause command received"
# "Starting recording (toggle mode)"
# "Stopping recording (toggle mode)"
```

## Expected Results

### ✅ Android Success Criteria
- [x] Single press activates/deactivates PTT
- [x] Long press does NOT trigger Google Assistant
- [x] Hold mode works correctly (press/release)
- [x] Toggle mode works correctly
- [x] Logs show "Long press detected - consuming" message

### ⚠️ iOS Expected Behavior
- [x] Single press activates/deactivates PTT (toggle mode)
- [x] Long press DOES trigger Siri (cannot be prevented)
- [x] Toggle mode recommended for iOS users
- [x] Hold mode not recommended on iOS

## Troubleshooting

### Issue: Button presses not detected at all

**Android:**
```bash
# Check if app has permissions
adb shell dumpsys package com.example.app | grep permission

# Reinstall app to ensure permissions requested
flutter clean
flutter run --release
```

**iOS:**
- Ensure app is in foreground
- Check Bluetooth connection in Settings
- Verify audio routing to headset

### Issue: Google Assistant still launches (Android)

**Possible causes:**
1. App not in foreground
2. OEM-specific Bluetooth stack behavior
3. Specific headset sends non-standard key codes

**Debug:**
```bash
# Check what key codes your headset sends
adb logcat | grep "keyCode="
```

### Issue: No audio/recording functionality

This test focuses on **button capture only**. Full audio recording/playback requires:
- Microphone permissions granted
- Audio recording service implemented
- Proper audio routing setup

## Next Steps After Testing

1. **If button capture works**:
   - ✅ Implement actual audio recording
   - ✅ Add WebRTC for real-time communication
   - ✅ Implement room/session management

2. **If issues found**:
   - 📋 Document specific device/headset model
   - 📋 Collect full logs
   - 📋 Note Android/iOS version
   - 📋 Share findings for further debugging

## Quick Reference

### Files Modified
- `packages/mobile/android/app/src/main/kotlin/com/example/app/MainActivity.kt` - Key event interception
- `packages/mobile/android/app/src/main/AndroidManifest.xml` - Added permission
- `packages/mobile/ios/Runner/AppDelegate.swift` - Documentation comments
- `docs/bluetooth-ptt-implementation.md` - Full technical documentation

### Key Code Changes
- **Android**: Added `dispatchKeyEvent()` override with long-press detection
- **Android**: Long-press events (repeatCount > 0) are consumed
- **Android**: Added MODIFY_AUDIO_SETTINGS permission
- **iOS**: Added documentation about Siri limitation

---

**Test Date**: _________________
**Device Model**: _________________
**Android/iOS Version**: _________________
**Headset Model**: _________________

**Results**:
- [ ] Single press works
- [ ] Long press handled correctly (Android) / Triggers Siri (iOS expected)
- [ ] Toggle mode works
- [ ] Hold mode works (Android only)

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
