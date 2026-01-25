import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ptt_state.dart';

class PTTService extends ChangeNotifier {
  static const platform = MethodChannel('com.example.peloton/ptt');

  PTTState _state = PTTState.idle;
  PTTConfiguration _config = const PTTConfiguration();

  PTTState get state => _state;
  PTTMode get mode => _config.mode;
  PTTButton get button => _config.button;
  PTTConfiguration get config => _config;

  PTTService() {
    _initializeNativeCommunication();
    _initializeWakeLock();
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

      notifyListeners();
    }
  }

  void setMode(PTTMode newMode) {
    updateConfiguration(_config.copyWith(mode: newMode));
  }

  void setButton(PTTButton newButton) {
    // Force toggle mode for play/pause button (MediaSession doesn't distinguish press/release well)
    if (newButton == PTTButton.playPause && _config.mode == PTTMode.hold) {
      debugPrint('Auto-switching to toggle mode for play/pause button');
      updateConfiguration(_config.copyWith(button: newButton, mode: PTTMode.toggle));
    } else {
      updateConfiguration(_config.copyWith(button: newButton));
    }
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

  // No need to override dispose if we're not doing anything beyond super.dispose()
}
