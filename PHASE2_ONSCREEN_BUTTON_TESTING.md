# Phase 2: On-Screen PTT Button - Testing Guide

## ✅ Implementation Complete

Phase 2 adds a large on-screen PTT button as a universal fallback that works on all devices.

### What's Been Implemented

#### Flutter/Dart Layer
- ✅ Interactive on-screen PTT button with `GestureDetector`
- ✅ Visual feedback (glow effect when on-screen button active)
- ✅ TAP/HOLD label based on mode
- ✅ Button-aware instruction text
- ✅ Current button configuration display
- ✅ WakeLock integration via `wakelock_plus` package

#### Wake Lock Support
- ✅ Prevents screen from sleeping during rides
- ✅ Configurable via `preventScreenLock` setting
- ✅ Cross-platform (Android + iOS)
- ✅ Automatic enable/disable based on configuration

---

## 🧪 Stage Gate 2: On-Screen Button Testing

**OBJECTIVE:** Validate that the on-screen PTT button works reliably as a universal fallback and that wake lock prevents screen sleep.

### Prerequisites

**Ensure Phase 1 is complete:**
- ⬜ Phase 1 tests passed
- ⬜ Volume buttons working on both platforms

**New dependencies:**
```bash
cd packages/mobile
flutter pub get  # Install wakelock_plus package
```

---

### Test Plan

## Test 1: On-Screen Button - Toggle Mode

**Setup:**
1. Launch app
2. Switch PTT button to "On-Screen Button" (future: via settings, now: default or debug)
3. Enable "Toggle Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Verify UI | Large button shows "TAP" label | ⬜ |
| 2 | Verify UI | Button has glowing shadow effect | ⬜ |
| 3 | Tap the button once | PTT activates (green, "RECORDING") | ⬜ |
| 4 | Verify instruction | Shows "Tap the button to stop recording" | ⬜ |
| 5 | Tap the button again | PTT deactivates (red, "READY") | ⬜ |
| 6 | Rapid tap 10 times | Toggles on/off reliably, no missed taps | ⬜ |
| 7 | Check logs | Shows "PTT State changed" messages | ⬜ |

**Acceptance Criteria:**
- ✅ On-screen button responds instantly to taps
- ✅ Visual feedback is clear (color change, glow)
- ✅ Toggle mode works reliably
- ✅ No missed or double triggers

---

## Test 2: On-Screen Button - Hold Mode

**Setup:**
1. Keep PTT button as "On-Screen Button"
2. Switch to "Hold Mode"

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Verify UI | Button shows "HOLD" label | ⬜ |
| 2 | Press and hold button (2s) | PTT active while holding (green) | ⬜ |
| 3 | Release button | PTT deactivates immediately (red) | ⬜ |
| 4 | Press and hold (5s) | PTT stays active entire time | ⬜ |
| 5 | Quick tap (< 0.5s) | PTT activates briefly then deactivates | ⬜ |
| 6 | Check instruction | Shows "Press and hold the button to record" | ⬜ |

**Acceptance Criteria:**
- ✅ Hold mode activates on long-press start
- ✅ Hold mode deactivates on long-press end
- ✅ No delay or lag in activation/deactivation
- ✅ Visual feedback immediate

---

## Test 3: Wake Lock - Screen Stays On

**Setup:**
1. Ensure "Prevent Screen Lock" is enabled (default)
2. Launch app

**Android Test:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app | Check logs: "WakeLock enabled" | ⬜ |
| 2 | Wait 1 minute without touching | Screen stays on | ⬜ |
| 3 | Wait 5 minutes without touching | Screen still on | ⬜ |
| 4 | Check battery settings | App uses "Screen On" permission | ⬜ |
| 5 | Press power button | Screen turns off (manual override works) | ⬜ |
| 6 | Press power again | Screen turns on, app still visible | ⬜ |

**iOS Test:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app | Check Xcode console: WakeLock enabled | ⬜ |
| 2 | Wait 1 minute without touching | Screen stays on | ⬜ |
| 3 | Wait 5 minutes without touching | Screen still on | ⬜ |
| 4 | Lock device manually | Screen turns off (manual override works) | ⬜ |
| 5 | Unlock device | App still in foreground | ⬜ |

**Acceptance Criteria:**
- ✅ Screen stays on indefinitely when app is active
- ✅ Manual power button/lock still works
- ✅ No excessive battery drain (check device battery stats)

---

## Test 4: Wake Lock - Disable Functionality

**Setup:**
1. In configuration, disable "Prevent Screen Lock"
2. Restart app (future: just toggle setting)

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app with setting OFF | Check logs: "WakeLock disabled" or not enabled | ⬜ |
| 2 | Wait for auto-lock timeout | Screen dims/locks per device settings | ⬜ |
| 3 | Re-enable "Prevent Screen Lock" | WakeLock activates, screen stays on | ⬜ |

**Acceptance Criteria:**
- ✅ Wake lock respects configuration setting
- ✅ Disabling allows normal screen lock behavior
- ✅ Enabling prevents screen lock

---

## Test 5: Button Configuration Display

**Setup:**
1. Launch app with different button configurations

**Test Steps:**
| Button | Icon | Display Name | Pass/Fail |
|--------|------|--------------|-----------|
| Volume Down | 🔉 | "Volume Down" | ⬜ |
| Volume Up | 🔊 | "Volume Up" | ⬜ |
| On-Screen | 📱 | "On-Screen Button" | ⬜ |
| Headset Play/Pause | 🎧 | "Headset Play/Pause" | ⬜ |

**Acceptance Criteria:**
- ✅ Current button configuration clearly displayed
- ✅ Icon + name visible at top of screen
- ✅ Instruction text adapts to button type

---

## Test 6: Cycling Use Case Simulation

**Real-world scenario:** Using app while cycling

**Setup:**
1. Enable "Prevent Screen Lock"
2. Set PTT button to "On-Screen Button"
3. Set mode to "Hold Mode"
4. Mount device on bike (or simulate)

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Start ride simulation (10 min) | Screen stays on entire time | ⬜ |
| 2 | Press PTT button with glove | Button activates reliably | ⬜ |
| 3 | Hold button while "talking" (30s) | PTT stays active, screen doesn't dim | ⬜ |
| 4 | Release button | PTT deactivates | ⬜ |
| 5 | Repeat 20 times during ride | All presses register correctly | ⬜ |
| 6 | Check battery after 30 min | Battery drain acceptable (< 10%/30min) | ⬜ |

**Acceptance Criteria:**
- ✅ On-screen button usable with cycling gloves
- ✅ Button size adequate (200x200px)
- ✅ Screen stays visible entire ride
- ✅ No performance issues or lag
- ✅ Acceptable battery consumption

---

## Test 7: Switching Between Button Types

**Setup:**
1. Start with Volume Down button
2. Activate PTT (recording)

**Test Steps:**
| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | While recording, switch to On-Screen | Recording stops, switches to on-screen | ⬜ |
| 2 | Verify button display | Shows "On-Screen Button" with icon | ⬜ |
| 3 | Tap on-screen button | PTT activates with on-screen button | ⬜ |
| 4 | Press Volume Down | No effect (not configured) | ⬜ |
| 5 | Switch back to Volume Down | On-screen button becomes passive indicator | ⬜ |
| 6 | Press Volume Down | PTT activates with volume button | ⬜ |

**Acceptance Criteria:**
- ✅ Switching buttons stops active recording
- ✅ Only configured button triggers PTT
- ✅ Visual indicator shows active button
- ✅ On-screen button only interactive when selected

---

## Cross-Platform Verification

**Compare Android vs iOS:**
| Feature | Android Result | iOS Result | Notes |
|---------|---------------|------------|-------|
| On-screen tap | ⬜ | ⬜ | Should be identical |
| On-screen hold | ⬜ | ⬜ | Should be identical |
| Wake lock ON | ⬜ | ⬜ | Should be identical |
| Wake lock OFF | ⬜ | ⬜ | Should be identical |
| Button size/usability | ⬜ | ⬜ | Should be identical |
| Battery usage (30 min) | ___% | ___% | Document actual |

---

## Known Issues & Limitations

### On-Screen Button
- ⚠️ Requires screen to be on (can't work from lock screen)
- ⚠️ May be difficult to use with thick winter gloves
- ⚠️ Accidental touches possible if device in pocket

### Wake Lock
- ⚠️ Battery drain during long rides (mitigated by design)
- ⚠️ May interfere with other apps' screen control
- ⚠️ User must remember to exit app to allow screen lock

---

## Troubleshooting

### On-Screen Button Not Responding

**Check Flutter console:**
```
# Should see when tapping:
PTT State changed to: active
```

**If button doesn't respond:**
1. Verify button config is "onScreen"
2. Check `GestureDetector` handlers in `home_screen.dart:22-34`
3. Try toggle vs hold mode

### Wake Lock Not Working

**Android:**
```bash
adb logcat | grep -i wakelock
# Should see: "WakeLock enabled"
```

**iOS:**
```
# Check Xcode console
# Should see: "WakeLock enabled"
```

**If wake lock fails:**
1. Check `wakelock_plus` package installed: `flutter pub get`
2. Verify `preventScreenLock` is `true` in config
3. Check device battery saver mode (may override)

### Battery Drain Issues

**Expected battery usage:**
- With wake lock ON: ~15-20% per hour
- With wake lock OFF: ~5-10% per hour

**If excessive drain:**
1. Check for other background apps
2. Verify screen brightness isn't at maximum
3. Consider disabling wake lock for short rides

---

## Success Criteria for Phase 2

### Must Have ✅
- [ ] On-screen button works in toggle mode
- [ ] On-screen button works in hold mode
- [ ] Wake lock prevents screen sleep
- [ ] Button size adequate for gloved use
- [ ] Visual feedback clear and immediate

### Nice to Have ⭐
- [ ] Haptic feedback on button press (future enhancement)
- [ ] Customizable button size (future enhancement)
- [ ] Battery usage optimization

### Known Limitations (Acceptable) ⚠️
- [ ] Requires screen to be on (documented)
- [ ] May be difficult with very thick gloves (volume buttons recommended)
- [ ] Battery usage higher with wake lock (documented)

---

## Next Steps After Phase 2 Validation

Once Phase 2 tests pass:

**✅ Approved to proceed → Phase 3: Settings UI**
- Create settings screen for button configuration
- Add platform-aware button selection
- Implement configuration persistence
- Test complete system end-to-end

**❌ Issues found → Fix before proceeding**
- Document failing tests
- Debug Flutter/native integration
- Iterate on UI/UX

---

## Testing Log

**Date:** ___________
**Tester:** ___________
**Devices Tested:**
- Android: ___________
- iOS: ___________

**Overall Result:** PASS / FAIL / NEEDS WORK

**Battery Usage Data:**
- Android (30 min): ____%
- iOS (30 min): ____%

**Notes:**
```
(Add any observations, issues, or recommendations here)
```

---

**Phase 2 Status:** ⬜ NOT TESTED | ⬜ IN PROGRESS | ⬜ PASSED | ⬜ FAILED
