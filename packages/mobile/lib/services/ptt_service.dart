import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ptt_state.dart';
import 'recorder_service.dart';

class PTTService extends ChangeNotifier {
  static const platform = MethodChannel('com.example.peloton/ptt');

  PTTState _state = PTTState.idle;
  PTTConfiguration _config = const PTTConfiguration();
  final RecorderService _recorder;

  PTTState get state => _state;
  PTTMode get mode => _config.mode;
  PTTButton get button => _config.button;
  PTTConfiguration get config => _config;

  PTTService({RecorderService? recorder})
      : _recorder = recorder ?? RecorderService() {
    _initializeNativeCommunication();
    _initializeWakeLock();
    _pushInitialConfigToNative();
  }

  // The native side keeps its own copy of pttMode/pttButton with defaults that may not
  // match the Dart defaults. Sync once at startup so the first headset press is handled
  // with the correct configuration instead of native defaults.
  void _pushInitialConfigToNative() async {
    try {
      await platform.invokeMethod('updatePTTConfiguration', {
        'mode': _config.mode.name,
        'button': _config.button.name,
        'preventScreenLock': _config.preventScreenLock,
      });
      debugPrint('PTT initial config pushed to native: mode=${_config.mode.name}, button=${_config.button.name}');
    } catch (e) {
      debugPrint('Error pushing initial PTT config to native: $e');
    }
  }

  void _initializeWakeLock() async {
    if (_config.preventScreenLock) {
      try {
        await WakelockPlus.enable();
        debugPrint('WakeLock enabled');
      } catch (e) {
        debugPrint('Failed to enable WakeLock: $e');
      }
    }
  }

  void _initializeNativeCommunication() {
    platform.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    debugPrint('Received native call: ${call.method}');

    switch (call.method) {
      case 'pttPressed':
        _setState(PTTState.active);
        break;
      case 'pttReleased':
        _setState(PTTState.idle);
        break;
      default:
        debugPrint('Unknown method: ${call.method}');
    }
  }

  void _setState(PTTState newState) {
    if (_state != newState) {
      _state = newState;
      debugPrint('PTT State changed to: $_state (Mode: ${_config.mode.displayName}, Button: ${_config.button.displayName})');
      // Drive recording lifecycle from state transitions so every press/release
      // path (system PTT, headset, on-screen, manual) goes through one place.
      if (newState == PTTState.active) {
        _recorder.startRecording();
      } else {
        _recorder.stopAndPlayback();
      }
      notifyListeners();
    }
  }

  Future<void> updateConfiguration(PTTConfiguration newConfig) async {
    if (_config.mode != newConfig.mode ||
        _config.button != newConfig.button ||
        _config.preventScreenLock != newConfig.preventScreenLock) {

      // If switching modes/buttons while recording, stop recording
      if (_state == PTTState.active) {
        _setState(PTTState.idle);
      }

      final oldPreventScreenLock = _config.preventScreenLock;
      _config = newConfig;
      debugPrint('PTT Configuration updated: Mode=${_config.mode.displayName}, Button=${_config.button.displayName}, PreventScreenLock=${_config.preventScreenLock}');

      // Update WakeLock if the setting changed
      if (oldPreventScreenLock != _config.preventScreenLock) {
        try {
          if (_config.preventScreenLock) {
            await WakelockPlus.enable();
            debugPrint('WakeLock enabled');
          } else {
            await WakelockPlus.disable();
            debugPrint('WakeLock disabled');
          }
        } catch (e) {
          debugPrint('Failed to update WakeLock: $e');
        }
      }

      // Notify native platform about configuration change
      try {
        await platform.invokeMethod('updatePTTConfiguration', {
          'mode': _config.mode.name,
          'button': _config.button.name,
          'preventScreenLock': _config.preventScreenLock,
        });
      } catch (e) {
        debugPrint('Error updating native configuration: $e');
      }

      // Manage iOS PushToTalk channel lifecycle when systemPTT is selected/deselected.
      try {
        if (_config.button == PTTButton.systemPTT) {
          await platform.invokeMethod('joinPTTChannel', {
            'name': 'Peloton PTT',
          });
        } else {
          await platform.invokeMethod('leavePTTChannel');
        }
      } catch (e) {
        debugPrint('Error toggling system PTT channel: $e');
      }

      notifyListeners();
    }
  }

  void setMode(PTTMode newMode) {
    updateConfiguration(_config.copyWith(mode: newMode));
  }

  void setButton(PTTButton newButton) {
    // Native code forces toggle semantics for play/pause keycodes regardless of mode,
    // so the user can keep hold mode (for volume buttons) without breaking play/pause.
    // The settings UI still hides hold mode when play/pause is selected for clarity.
    updateConfiguration(_config.copyWith(button: newButton));
  }

  void setPreventScreenLock(bool prevent) {
    updateConfiguration(_config.copyWith(preventScreenLock: prevent));
  }

  // Manual trigger for testing (fallback when native doesn't work)
  void manualPress() {
    _setState(PTTState.active);
  }

  void manualRelease() {
    _setState(PTTState.idle);
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
