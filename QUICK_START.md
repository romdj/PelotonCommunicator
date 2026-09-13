# Quick Start Guide - Configurable PTT System

## 🚀 5-Minute Setup

### Step 1: Install Dependencies
```bash
cd packages/mobile
flutter pub get
```

### Step 2: Deploy to Device
```bash
# Android
flutter run

# iOS
flutter run

# Or specify device:
flutter devices
flutter run --device-id=<device-id>
```

### Step 3: Configure PTT
1. Tap **Settings icon** (top-right)
2. Select **Volume Down** button
3. Keep **Toggle Mode** (default)
4. Ensure **Prevent Screen Lock** is ON
5. Tap **Back**

### Step 4: Test
1. Press **Volume Down** → PTT activates (green)
2. Press **Volume Down** again → PTT deactivates (red)
3. ✅ **Android:** Long-press should NOT trigger Google Assistant
4. ⚠️ **iOS:** Long-press may trigger Siri (known limitation)

---

## 📱 Recommended Configurations

### For Cycling (Recommended)
```
Button: Volume Down 🔉
Mode:   Hold (press and hold to talk)
Lock:   ON (keep screen on)
```
**Why:** Easy to press with gloves, hands-free hold mode

### For Testing
```
Button: On-Screen Button 📱
Mode:   Toggle (tap to start/stop)
Lock:   ON
```
**Why:** Reliable, works everywhere, no hardware required

### For Bluetooth Headset
```
Button: Headset Next Track ⏭️
Mode:   Toggle
Lock:   ON
```
**Why:** No Siri/Assistant conflict, dedicated button

---

## 🔍 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Volume button doesn't work | Use physical device (not emulator) |
| Google Assistant activates | Check Android logs for "consuming" message |
| Siri activates (iOS) | Expected - use toggle mode with quick taps |
| Screen locks | Enable "Prevent Screen Lock" in settings |
| Button not responding | Verify correct button selected in settings |

---

## 📋 Testing Checklist

Quick validation (5 minutes):
- [ ] Volume Down activates PTT
- [ ] On-screen button works
- [ ] Settings screen accessible
- [ ] Mode switching works
- [ ] Screen stays on with wake lock
- [ ] Long-press doesn't trigger Assistant (Android)

Full validation (30 minutes):
- [ ] Complete PHASE1_VOLUME_BUTTON_TESTING.md
- [ ] Complete PHASE2_ONSCREEN_BUTTON_TESTING.md
- [ ] Complete PHASE3_SETTINGS_UI_TESTING.md

---

## 📚 Documentation

- **PTT_IMPLEMENTATION_SUMMARY.md** - Complete overview
- **PHASE1_VOLUME_BUTTON_TESTING.md** - Volume button tests
- **PHASE2_ONSCREEN_BUTTON_TESTING.md** - On-screen button tests
- **PHASE3_SETTINGS_UI_TESTING.md** - Settings UI tests

---

## 🎯 Success in 3 Commands

```bash
# 1. Install
cd packages/mobile && flutter pub get

# 2. Run
flutter run

# 3. Test
# Press Volume Down → PTT should activate
```

**That's it! You're ready to test. 🎉**
