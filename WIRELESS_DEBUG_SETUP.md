# Android Wireless Debugging Setup Guide

## Quick Setup (3 Methods)

You can use **any** of these methods. Method 1 is recommended for first-time setup.

---

## Method 1: Wireless Debugging (Android 11+) - RECOMMENDED

### Step 1: Enable Developer Options on Your Android Device

1. **Open Settings** on your Android device
2. **Scroll to "About phone"** (or "About device")
3. **Tap "Build number" 7 times** rapidly
4. You'll see a message: "You are now a developer!"

### Step 2: Enable Wireless Debugging

1. **Go back to Settings**
2. **Tap "System"** → **"Developer options"**
3. **Toggle ON "Developer options"** (at the top)
4. **Scroll down and toggle ON "Wireless debugging"**
5. **Tap "Wireless debugging"** to enter the submenu

### Step 3: Pair Your Device

**On Your Android Device:**
1. In "Wireless debugging", tap **"Pair device with pairing code"**
2. You'll see:
   - **6-digit pairing code** (e.g., 123456)
   - **IP address and port** (e.g., 192.168.1.100:37853)

**On Your Mac (Terminal):**
```bash
# Add ADB to your PATH for this session
export PATH="$PATH:/Users/romdj/Library/Android/sdk/platform-tools"

# Pair with your device (replace with YOUR IP and port from device screen)
adb pair 192.168.1.100:37853

# When prompted, enter the 6-digit pairing code from your device
```

**Expected output:**
```
Enter pairing code: 123456
Successfully paired to 192.168.1.100:37853 [guid=adb-ABCD1234-XYZ789]
```

### Step 4: Connect to Your Device

**On Your Android Device:**
1. Go back to "Wireless debugging" main screen
2. Note the **IP address & port** shown (different from pairing port!)
   - Example: `192.168.1.100:40587`

**On Your Mac:**
```bash
# Connect to device (use the IP:port from "Wireless debugging" screen, NOT pairing)
adb connect 192.168.1.100:40587
```

**Expected output:**
```
connected to 192.168.1.100:40587
```

### Step 5: Verify Connection

```bash
adb devices
```

**Expected output:**
```
List of devices attached
192.168.1.100:40587    device
```

### Step 6: Test with Flutter

```bash
flutter devices
```

**Expected output:**
```
Found 3 connected devices:
  sdk gphone64 arm64 (mobile) • 192.168.1.100:40587 • android-arm64  • Android 13 (API 33)
  macOS (desktop)             • macos                • darwin-arm64   • macOS 26.1 25B78 darwin-arm64
  Chrome (web)                • chrome               • web-javascript • Google Chrome 142.0.7444.176
```

✅ **Success!** Your device is now wirelessly connected.

---

## Method 2: USB Debugging First, Then Switch to Wireless

### Step 1: Connect via USB

1. **Connect your Android device to Mac via USB cable**
2. **Enable USB debugging:**
   - Settings → Developer options → USB debugging → Toggle ON
3. **On device:** Tap "Allow" when prompted "Allow USB debugging?"

### Step 2: Verify USB Connection

```bash
export PATH="$PATH:/Users/romdj/Library/Android/sdk/platform-tools"
adb devices
```

Should show:
```
List of devices attached
ABC123XYZ    device
```

### Step 3: Enable TCP/IP Mode

```bash
# Switch ADB to wireless mode on port 5555
adb tcpip 5555
```

### Step 4: Get Device IP Address

**On Your Android Device:**
- Settings → About phone → Status → IP address
- **OR** Settings → Network & Internet → Wi-Fi → Tap connected network → IP address

**OR on Mac:**
```bash
adb shell ip route
```
Look for output like: `192.168.1.100 dev wlan0`

### Step 5: Disconnect USB and Connect Wirelessly

```bash
# Disconnect USB cable physically

# Connect wirelessly (replace with your device's IP)
adb connect 192.168.1.100:5555
```

### Step 6: Verify

```bash
adb devices
flutter devices
```

✅ **Success!** Now wireless.

---

## Method 3: QR Code Pairing (Some Android Devices)

### Step 1: Enable Wireless Debugging

Same as Method 1 - Settings → Developer options → Wireless debugging → ON

### Step 2: Use QR Code

1. **On device:** Tap "Pair device with QR code"
2. **On Mac:** Generate pairing QR code:
   ```bash
   # Note: This requires additional setup and may not be available
   # Stick with Method 1 or 2 for simplicity
   ```

---

## Troubleshooting

### Issue: "command not found: adb"

**Solution:** Add ADB to your PATH permanently

```bash
# Edit your shell config file
nano ~/.zshrc

# Add this line at the end:
export PATH="$PATH:/Users/romdj/Library/Android/sdk/platform-tools"

# Save (Ctrl+O, Enter, Ctrl+X)

# Reload config
source ~/.zshrc

# Test
adb devices
```

### Issue: "No devices found"

**Checklist:**
- [ ] Both Mac and Android on **same Wi-Fi network**
- [ ] Wireless debugging is **enabled** on device
- [ ] You used the **correct IP address and port**
- [ ] Firewall isn't blocking connection

**Solution:**
```bash
# 1. Restart ADB server
adb kill-server
adb start-server

# 2. Try connecting again
adb connect <your-ip>:<your-port>
```

### Issue: "device offline"

**Solution:**
```bash
# Disconnect and reconnect
adb disconnect
adb connect <your-ip>:<your-port>
```

### Issue: Connection keeps dropping

**Reasons:**
- Device goes to sleep (screen off too long)
- Wi-Fi power saving enabled
- Device switches Wi-Fi networks

**Solution:**
```bash
# Keep device screen on while developing
# Settings → Developer options → Stay awake → Toggle ON

# OR re-connect when it drops
adb connect <your-ip>:<your-port>
```

### Issue: "Wireless debugging" option not available

**Reason:** Android version < 11

**Solution:** Use Method 2 (USB first, then wireless via `adb tcpip 5555`)

### Issue: Can't find IP address

**Solutions:**
```bash
# Method 1: Via ADB shell (if USB connected)
adb shell ip route

# Method 2: On device
# Settings → About phone → Status → IP address

# Method 3: Via network settings
# Settings → Network & Internet → Wi-Fi → Tap connected network → Advanced → IP address
```

---

## Permanent ADB Path Setup (Recommended)

To avoid typing the PATH export every time:

```bash
# Open your shell config
nano ~/.zshrc

# Add this line at the end:
export PATH="$PATH:/Users/romdj/Library/Android/sdk/platform-tools"

# Save and exit (Ctrl+O, Enter, Ctrl+X)

# Reload
source ~/.zshrc
```

Now `adb` will work in all new terminal sessions!

---

## Quick Reference Commands

```bash
# Check connected devices
adb devices
flutter devices

# Pair device (Android 11+)
adb pair <ip>:<port>

# Connect wirelessly
adb connect <ip>:<port>

# Disconnect
adb disconnect

# Switch to wireless mode (USB connected)
adb tcpip 5555

# Switch back to USB mode
adb usb

# Restart ADB server
adb kill-server
adb start-server

# View device logs (useful for debugging PTT)
adb logcat | grep PTT
```

---

## Next Steps After Connection

Once your device shows in `flutter devices`:

```bash
# Deploy and run the PTT app
cd packages/mobile
flutter run

# Or specify the device explicitly
flutter run --device-id=<device-id>

# For release builds
flutter run --release
```

---

## Testing PTT Features

Once the app is running:

1. **Open logcat in another terminal:**
   ```bash
   adb logcat | grep PTT
   ```

2. **Test volume buttons:**
   - Press Volume Down → Should see "PTT State changed to: active"
   - Press again → Should see "PTT State changed to: idle"

3. **Test long-press prevention:**
   - Long-press Volume Down (>1s)
   - Should see: "Long press detected - consuming to prevent voice assistant"
   - Google Assistant should NOT activate ✅

4. **Follow testing guides:**
   - `PHASE1_VOLUME_BUTTON_TESTING.md`
   - `PHASE2_ONSCREEN_BUTTON_TESTING.md`
   - `PHASE3_SETTINGS_UI_TESTING.md`

---

## Common Device-Specific Notes

### Samsung Devices
- Developer options often under "Developer options" directly in main Settings

### Pixel Devices
- Wireless debugging very reliable
- Settings → System → Developer options → Wireless debugging

### OnePlus/Oppo Devices
- May need to enable OEM unlocking
- Settings → Developer options → OEM unlocking → Toggle ON

---

## Summary - Choose Your Method

| Method | Best For | Requirements |
|--------|---------|--------------|
| **Method 1** | Android 11+ | Wi-Fi, no cable needed after pairing |
| **Method 2** | Any Android | USB cable initially, then wireless |
| **Method 3** | QR support | Some devices only |

**Recommended:** Start with **Method 1** if your device has Android 11+.

---

## Quick Start (Copy-Paste)

```bash
# 1. Add ADB to PATH (one-time setup)
echo 'export PATH="$PATH:/Users/romdj/Library/Android/sdk/platform-tools"' >> ~/.zshrc
source ~/.zshrc

# 2. On device: Settings → Developer options → Wireless debugging → Pair device with pairing code

# 3. Pair (replace IP:PORT and CODE with values from your device)
adb pair 192.168.1.100:XXXXX
# Enter pairing code when prompted

# 4. Connect (use IP:PORT from main Wireless debugging screen)
adb connect 192.168.1.100:XXXXX

# 5. Verify
adb devices
flutter devices

# 6. Run app
cd packages/mobile
flutter run
```

**That's it!** 🚀
