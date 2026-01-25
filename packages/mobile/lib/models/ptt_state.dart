enum PTTState {
  idle, // Red icon - button not pressed
  active, // Green icon - button pressed
}

enum PTTMode {
  toggle, // Press once to start, press again to stop (current working mode)
  hold, // Long press and hold to record, release to stop (traditional PTT)
}

enum PTTButton {
  // On-screen
  onScreen,

  // Volume buttons (device + Bluetooth headset - note: BT volume buttons don't work)
  volume,

  // Play/Pause button (Bluetooth headset + wired headset)
  playPause,

  // iOS 16+ PushToTalk framework
  systemPTT, // iOS 16+ only
}

class PTTConfiguration {
  final PTTMode mode;
  final PTTButton button;
  final bool preventScreenLock;

  const PTTConfiguration({
    this.mode = PTTMode.toggle,
    this.button = PTTButton.volume,
    this.preventScreenLock = true,
  });

  PTTConfiguration copyWith({
    PTTMode? mode,
    PTTButton? button,
    bool? preventScreenLock,
  }) {
    return PTTConfiguration(
      mode: mode ?? this.mode,
      button: button ?? this.button,
      preventScreenLock: preventScreenLock ?? this.preventScreenLock,
    );
  }
}

extension PTTStateExtension on PTTState {
  bool get isActive => this == PTTState.active;
  bool get isIdle => this == PTTState.idle;
}

extension PTTModeExtension on PTTMode {
  bool get isToggle => this == PTTMode.toggle;
  bool get isHold => this == PTTMode.hold;

  String get displayName =>
      this == PTTMode.toggle ? 'Toggle Mode' : 'Hold Mode';
  String get description => this == PTTMode.toggle
      ? 'Press once to start, press again to stop'
      : 'Hold button to record, release to stop';
}

extension PTTButtonExtension on PTTButton {
  String get displayName {
    switch (this) {
      case PTTButton.onScreen:
        return 'On-Screen Button';
      case PTTButton.volume:
        return 'Volume Buttons';
      case PTTButton.playPause:
        return 'Play/Pause Button';
      case PTTButton.systemPTT:
        return 'System PTT (iOS 16+)';
    }
  }

  bool get isAvailableOnAndroid {
    return this != PTTButton.systemPTT;
  }

  String get description {
    switch (this) {
      case PTTButton.onScreen:
        return 'Large on-screen button (works everywhere)';
      case PTTButton.volume:
        return 'Device volume buttons - works with device & most wired headsets (BT headset volume buttons unsupported)';
      case PTTButton.playPause:
        return 'Play/pause button on Bluetooth or wired headsets';
      case PTTButton.systemPTT:
        return 'System PTT interface - works from lock screen (iOS 16+)';
    }
  }

  String get icon {
    switch (this) {
      case PTTButton.onScreen:
        return '📱';
      case PTTButton.volume:
        return '🔊';
      case PTTButton.playPause:
        return '🎧';
      case PTTButton.systemPTT:
        return '🍎';
    }
  }

  bool get requiresBackgroundService {
    // Volume buttons need accessibility service for background on Android
    return this == PTTButton.volume;
  }
}
