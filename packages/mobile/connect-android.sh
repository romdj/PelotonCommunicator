#!/bin/bash
# Quick Android Wireless Debug Connection Script

echo "🔧 Android Wireless Debug Helper"
echo "================================"
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found in PATH"
    echo "Run: export PATH=\"\$PATH:/Users/romdj/Library/Android/sdk/platform-tools\""
    exit 1
fi

echo "📱 Current connected devices:"
adb devices
echo ""

# Show menu
echo "Choose an option:"
echo "1) Pair new device (Android 11+)"
echo "2) Connect to device"
echo "3) Disconnect all"
echo "4) Restart ADB server"
echo "5) Check Flutter devices"
echo "6) View PTT logs"
echo "7) Deploy PTT app"
echo "0) Exit"
echo ""
read -p "Enter option (0-7): " option

case $option in
    1)
        echo ""
        echo "📱 On your Android device:"
        echo "   Settings → Developer options → Wireless debugging"
        echo "   → Tap 'Pair device with pairing code'"
        echo ""
        read -p "Enter IP:PORT from device (e.g., 192.168.1.100:37853): " pair_address
        adb pair "$pair_address"
        echo ""
        echo "✅ Pairing complete! Now connect using option 2"
        ;;
    2)
        echo ""
        echo "📱 On your Android device:"
        echo "   Check 'Wireless debugging' screen for IP address & port"
        echo "   (This is DIFFERENT from the pairing port!)"
        echo ""
        read -p "Enter IP:PORT (e.g., 192.168.1.100:40587): " connect_address
        adb connect "$connect_address"
        echo ""
        echo "Checking connection..."
        sleep 1
        adb devices
        ;;
    3)
        echo ""
        echo "Disconnecting all devices..."
        adb disconnect
        adb devices
        ;;
    4)
        echo ""
        echo "Restarting ADB server..."
        adb kill-server
        sleep 1
        adb start-server
        echo "✅ ADB server restarted"
        ;;
    5)
        echo ""
        echo "Flutter devices:"
        flutter devices
        ;;
    6)
        echo ""
        echo "📋 Watching PTT logs (Ctrl+C to stop)..."
        echo "Press Volume Down on your device to see logs"
        echo ""
        adb logcat | grep --color=always PTT
        ;;
    7)
        echo ""
        echo "🚀 Deploying PTT app..."
        cd packages/mobile
        flutter run
        ;;
    0)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac
