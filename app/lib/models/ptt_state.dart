enum PTTState {
  idle,    // Red icon - button not pressed
  active,  // Green icon - button pressed
}

enum PTTMode {
  toggle,  // Press once to start, press again to stop (current working mode)
  hold,    // Long press and hold to record, release to stop (traditional PTT)
}

extension PTTStateExtension on PTTState {
  bool get isActive => this == PTTState.active;
  bool get isIdle => this == PTTState.idle;
}

extension PTTModeExtension on PTTMode {
  bool get isToggle => this == PTTMode.toggle;
  bool get isHold => this == PTTMode.hold;
  
  String get displayName => this == PTTMode.toggle ? 'Toggle Mode' : 'Hold Mode';
  String get description => this == PTTMode.toggle 
      ? 'Press once to start, press again to stop'
      : 'Hold button to record, release to stop';
}