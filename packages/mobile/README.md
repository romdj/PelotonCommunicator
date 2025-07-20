# Peloton Communicator Mobile App

Flutter cross-platform mobile application providing push-to-talk communication functionality with Bluetooth headset support.

## 🎯 Features

- **Push-to-Talk (PTT)** with dual interaction modes
- **Bluetooth Headset Integration** for hands-free operation  
- **Cross-Platform Support** for iOS and Android
- **Real-time State Management** with Provider pattern
- **Native Platform Integration** via Method Channels

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point
├── models/                # Data models and state classes
│   └── ptt_state.dart     # PTT state enums and extensions
├── services/              # Business logic and platform communication
│   └── ptt_service.dart   # Core PTT functionality and Method Channel
└── ui/                    # User interface components
    └── screens/
        └── home_screen.dart # Main app screen with PTT controls
```

### Platform-Specific Code

#### Android (`android/`)
- **MediaSessionCompat** for aggressive media button capture
- **Audio focus management** to override system voice assistant
- **Bluetooth permissions** and runtime permission handling
- **Kotlin implementation** in `MainActivity.kt`

#### iOS (`ios/`)
- **MPRemoteCommandCenter** for media button handling
- **AVAudioSession** configuration for audio priority
- **Swift implementation** in `AppDelegate.swift`
- **Note**: Limited by iOS system restrictions on media button capture

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** >= 3.2.0
- **Android Studio** / **Xcode** for platform-specific development
- **Physical devices** recommended for Bluetooth testing

### Installation
```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>
```

## 🎮 Usage

### PTT Modes

#### Toggle Mode (Recommended)
- **Press once** to start recording (icon turns green)
- **Press again** to stop recording (icon turns red)
- **Works reliably** on Android with Bluetooth headsets

#### Hold Mode (Limited)
- **Hold button** to record, **release** to stop
- **iOS limitation**: Works as toggle due to platform restrictions
- **Android**: May trigger system voice assistant on long press

---

For questions or support, please see the [main project documentation](../../README.md).
