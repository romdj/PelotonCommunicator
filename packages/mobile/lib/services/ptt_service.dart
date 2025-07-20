import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ptt_state.dart';

class PTTService extends ChangeNotifier {
  static const platform = MethodChannel('com.example.peloton/ptt');

  PTTState _state = PTTState.idle;
  PTTMode _mode = PTTMode.toggle; // Default to toggle mode (working mode)

  PTTState get state => _state;
  PTTMode get mode => _mode;

  PTTService() {
    _initializeNativeCommunication();
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
      debugPrint('PTT State changed to: $_state (Mode: ${_mode.displayName})');
      notifyListeners();
    }
  }

  void setMode(PTTMode newMode) {
    if (_mode != newMode) {
      // If switching modes while recording, stop recording
      if (_state == PTTState.active) {
        _setState(PTTState.idle);
      }

      _mode = newMode;
      debugPrint('PTT Mode changed to: ${_mode.displayName}');

      // Notify Android about the mode change
      platform.invokeMethod('setPTTMode', _mode.name);

      notifyListeners();
    }
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
    super.dispose();
  }
}
