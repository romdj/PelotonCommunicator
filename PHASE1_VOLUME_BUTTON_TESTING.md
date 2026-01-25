# Phase 1: Volume Button PTT - Testing Guide

## ✅ Implementation Complete

Phase 1 implements configurable button support with volume buttons as the primary PTT trigger.

### What's Been Implemented

#### Flutter/Dart Layer
- ✅ `PTTButton` enum with all button types
- ✅ `PTTConfiguration` class for managing button/mode/settings
- ✅ Updated `PTTService` to handle configuration changes
- ✅ Method channel communication for configuration updates

#### Android Layer (`MainActivity.kt`)
- ✅ Volume Down button capture (default)
- ✅ Volume Up button capture
- ✅ Headset Play/Pause button (existing)
- ✅ Headset Next/Previous track buttons
- ✅ Camera button support
- ✅ Long-press detection to prevent Google Assistant
- ✅ Screen wake lock support
- ✅ Configurable button routing via `dispatchKeyEvent()`

#### iOS Layer (`AppDelegate.swift`)
- ✅ Volume button observer using KVO
- ✅ Volume Up/Down button differentiation
- ✅ Headset button support via `MPRemoteCommandCenter`
- ✅ Screen idle timer disable support
- ✅ Volume reset to prevent actual volume changes
- ✅ Dynamic button listener reconfiguration

---

## 🧪 Stage Gate 1: Volume Button Testing

**OBJECTIVE:** Validate that volume buttons work reliably for PTT on both platforms without triggering voice assistants.

### Prerequisites

1. **Physical Devices Required**
   - Android device (Android 10+)
   - iOS device (iOS 14+)
   - Bluetooth headset (optional, for headset button testing)

2. **Build the App**
   ```bash
   cd packages/mobile
   flutter clean
   flutter pub get
   flutter build apk --debug    # For Android
   flutter build ios --debug     # For iOS
   ```

3. **Deploy to Devices**
   ```bash
   # Android
   flutter run --device-id=<your-android-device-id>

   # iOS
   flutter run --device-id=<your-ios-device-id>
   ```

---

### Test Plan

## Android Testing

### Test 1: Volume Down Button (Default)

**Setup:**
1. Launch app on Android device
2. Verify default configuration shows "Volume Down" button
3. Enable PTT "Toggle Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Press Volume Down once | PTT activates (green icon, "RECORDING") | ⬜ |
| 2 | Verify logs | `adb logcat \| grep PTT` shows "Starting recording (toggle mode)" | ⬜ |
| 3 | Press Volume Down again | PTT deactivates (red icon, "READY") | ⬜ |
| 4 | Verify logs | Shows "Stopping recording (toggle mode)" | ⬜ |
| 5 | **CRITICAL:** Long-press Volume Down (>1s) | Google Assistant DOES NOT activate | ⬜ |
| 6 | Verify logs | Shows "Long press detected - consuming to prevent voice assistant" | ⬜ |

**Acceptance Criteria:**
- ✅ Volume Down triggers PTT in both toggle and hold modes
- ✅ Google Assistant does NOT activate on long-press
- ✅ System volume does NOT change during PTT use

### Test 2: Volume Up Button

**Setup:**
1. Switch PTT button to "Volume Up" (we'll add UI in Phase 3, for now use debug)
2. Enable PTT "Hold Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Press and hold Volume Up | PTT activates immediately | ⬜ |
| 2 | Release Volume Up | PTT deactivates immediately | ⬜ |
| 3 | Rapid press/release 5 times | Only actual presses register (debouncing works) | ⬜ |
| 4 | Long-press Volume Up (>1s) | Google Assistant DOES NOT activate | ⬜ |

**Acceptance Criteria:**
- ✅ Volume Up triggers PTT reliably
- ✅ Hold mode works correctly (press/release)
- ✅ Debouncing prevents accidental double triggers

### Test 3: Screen Wake Lock

**Setup:**
1. Enable "Prevent Screen Lock" in configuration
2. Launch app

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Wait 30 seconds without touching device | Screen stays on | ⬜ |
| 2 | Wait 2 minutes without touching device | Screen still stays on | ⬜ |
| 3 | Disable "Prevent Screen Lock" | Screen lock resumes normal behavior | ⬜ |

---

## iOS Testing

### Test 4: Volume Down Button

**Setup:**
1. Launch app on iOS device
2. Verify default configuration shows "Volume Down" button
3. Enable PTT "Toggle Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Press Volume Down once | PTT activates (green icon, "RECORDING") | ⬜ |
| 2 | Check Xcode console | Shows "Volume button pressed: volumeDown" | ⬜ |
| 3 | Press Volume Down again | PTT deactivates (red icon, "READY") | ⬜ |
| 4 | Verify volume level | System volume DOES NOT change | ⬜ |
| 5 | Long-press Volume Down | **NOTE:** Siri MAY activate (known iOS limitation) | ⬜ |

**Acceptance Criteria:**
- ✅ Volume Down triggers PTT in toggle mode
- ✅ System volume does NOT change (or resets quickly)
- ⚠️ Siri activation on long-press is acceptable (document as known limitation)

### Test 5: Volume Up Button

**Setup:**
1. Switch to "Volume Up" button
2. Enable PTT "Toggle Mode" (recommended for iOS)

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Press Volume Up once | PTT activates | ⬜ |
| 2 | Press Volume Up again | PTT deactivates | ⬜ |
| 3 | Verify volume | System volume restored to original level | ⬜ |

### Test 6: Headset Buttons (iOS)

**Setup:**
1. Connect Bluetooth headset
2. Switch to "Headset Play/Pause" button
3. Enable PTT "Toggle Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Single-press headset button | PTT toggles on/off | ⬜ |
| 2 | Long-press headset button | **Siri WILL activate** (expected) | ⬜ |
| 3 | Switch to "Headset Next Track" | Use double-press for PTT | ⬜ |
| 4 | Double-press headset button | PTT toggles, NO Siri | ⬜ |

---

## Cross-Platform Testing

### Test 7: Configuration Persistence (Future)

**NOTE:** This test will be fully enabled in Phase 3 with settings UI

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Set button to Volume Up | Configuration updates | ⬜ |
| 2 | Kill and restart app | Volume Up still selected | ⬜ |
| 3 | Change to Hold mode | Mode persists across restarts | ⬜ |

---

## Troubleshooting

### Android Issues

**Volume doesn't trigger PTT:**
```bash
# Check logs
adb logcat | grep PTT

# Look for:
# - "dispatchKeyEvent: keyCode=25" (Volume Down)
# - "dispatchKeyEvent: keyCode=24" (Volume Up)
# - "Handling PTT event for button: volumeDown"
```

**Google Assistant still activating:**
```bash
# Verify long-press detection
adb logcat | grep "Long press detected"

# Should see: "consuming to prevent voice assistant"
```

**System volume changing:**
- This is expected briefly on iOS (will reset)
- On Android, should NOT change at all

### iOS Issues

**Volume button not working:**
```
# Check Xcode console for:
# - "Volume button observer started for: volumeDown"
# - "Volume button pressed: volumeDown"
```

**Siri keeps interrupting:**
- This is a **known iOS limitation** for long-press
- Recommend using **toggle mode** with quick single presses
- Consider using **Headset Next/Previous** buttons instead (no Siri conflict)

**Volume changes not resetting:**
- Check `MPVolumeView` slider access in logs
- May need additional permissions or delay adjustment

---

## Success Criteria for Phase 1

### Must Have ✅
- [ ] Volume Down works on Android (toggle & hold modes)
- [ ] Volume Down works on iOS (toggle mode)
- [ ] Google Assistant does NOT activate on Android long-press
- [ ] Screen wake lock works on both platforms
- [ ] No system volume changes (or quick reset on iOS)

### Nice to Have ⭐
- [ ] Volume Up also works reliably
- [ ] Headset buttons work as alternatives
- [ ] Camera button works (Android only)
- [ ] Smooth volume reset on iOS (imperceptible)

### Known Limitations (Acceptable) ⚠️
- [ ] iOS Siri activation on long-press (documented)
- [ ] Brief volume change on iOS before reset (documented)
- [ ] Volume buttons in background require accessibility service (Phase 4)

---

## Next Steps After Phase 1 Validation

Once Phase 1 tests pass:

**✅ Approved to proceed → Phase 2: On-Screen PTT Button**
- Add large on-screen button with `GestureDetector`
- Implement wake lock package
- Test on-screen button as universal fallback

**❌ Issues found → Fix before proceeding**
- Document failing tests
- Debug using platform logs
- Iterate on native implementations

---

## Testing Log

**Date:** ___________
**Tester:** ___________
**Devices Tested:**
- Android: ___________
- iOS: ___________

**Overall Result:** PASS / FAIL / NEEDS WORK

**Notes:**
```
(Add any observations, issues, or recommendations here)
```

---

**Phase 1 Status:** ⬜ NOT TESTED | ⬜ IN PROGRESS | ⬜ PASSED | ⬜ FAILED
