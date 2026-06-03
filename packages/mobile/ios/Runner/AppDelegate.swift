import UIKit
import Flutter
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.peloton/ptt"
  private var pttMode = "toggle" // Current PTT mode (toggle or hold)
  private var pttButton = "volumeDown" // Current PTT button configuration
  private var preventScreenLock = true // Keep screen on during rides
  private var isRecording = false
  private var lastPressTime = 0.0
  private let DOUBLE_PRESS_INTERVAL = 0.3 // 300ms to prevent accidental double press
  private var volumeButtonObserver: VolumeButtonObserver?
  private var systemPTTManager: Any? // PTTSystemManager (iOS 16+) — typed as Any so file compiles on older SDKs

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let pttChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    // Setup method call handler for Flutter->iOS communication
    pttChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setPTTMode":
        if let mode = call.arguments as? String {
          self?.pttMode = mode
          print("PTT mode set to: \(mode)")
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid PTT mode", details: nil))
        }
      case "updatePTTConfiguration":
        if let args = call.arguments as? [String: Any] {
          if let mode = args["mode"] as? String {
            self?.pttMode = mode
          }
          if let button = args["button"] as? String {
            self?.pttButton = button
            // Reconfigure button listeners based on new button type
            self?.configureButtonListeners(button: button, channel: pttChannel)
          }
          if let preventLock = args["preventScreenLock"] as? Bool {
            self?.preventScreenLock = preventLock
            // Update idle timer based on setting
            UIApplication.shared.isIdleTimerDisabled = preventLock
          }
          print("Configuration updated: mode=\(self?.pttMode ?? ""), button=\(self?.pttButton ?? ""), preventScreenLock=\(self?.preventScreenLock ?? false)")
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
        }
      case "joinPTTChannel":
        if #available(iOS 16.0, *) {
          let args = call.arguments as? [String: Any]
          let name = args?["name"] as? String ?? "Peloton PTT"
          let uuid = args?["uuid"] as? String
          let manager = (self?.systemPTTManager as? PTTSystemManager)
            ?? PTTSystemManager(channel: pttChannel)
          self?.systemPTTManager = manager
          manager.joinChannel(name: name, uuidString: uuid, result: result)
        } else {
          result(FlutterError(code: "UNSUPPORTED_OS", message: "PushToTalk requires iOS 16+", details: nil))
        }
      case "leavePTTChannel":
        if #available(iOS 16.0, *), let manager = self?.systemPTTManager as? PTTSystemManager {
          manager.leaveChannel(result: result)
        } else {
          result(nil)
        }
      case "beginSystemPTTTransmit":
        if #available(iOS 16.0, *), let manager = self?.systemPTTManager as? PTTSystemManager {
          manager.beginTransmitting(result: result)
        } else {
          result(FlutterError(code: "NO_MANAGER", message: "PTT manager not initialised", details: nil))
        }
      case "stopSystemPTTTransmit":
        if #available(iOS 16.0, *), let manager = self?.systemPTTManager as? PTTSystemManager {
          manager.stopTransmitting(result: result)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    setupAudioSession()
    setupRemoteCommandCenter(channel: pttChannel)
    configureButtonListeners(button: pttButton, channel: pttChannel)
    
    // Add notification observers for additional debugging
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      print("Audio route changed - checking for headset connection")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      
      // Use playAndRecord to get more control and avoid the defaultToSpeaker error
      try audioSession.setCategory(
        .playAndRecord,
        mode: .default,
        options: [
          .allowBluetooth,
          .allowBluetoothA2DP,
          .defaultToSpeaker,
          .duckOthers,
          .mixWithOthers
        ]
      )
      
      // Set higher priority and become the active audio session
      try audioSession.setActive(true, options: [])
      print("Audio session configured successfully with playAndRecord category")
    } catch {
      print("Failed to setup audio session: \(error)")
      
      // Fallback to simpler configuration
      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowBluetooth, .allowBluetoothA2DP])
        try AVAudioSession.sharedInstance().setActive(true)
        print("Audio session configured with fallback settings")
      } catch {
        print("Even fallback audio session failed: \(error)")
      }
    }
  }
  
  private func setupRemoteCommandCenter(channel: FlutterMethodChannel) {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Disable ALL commands first to clear any existing handlers
    commandCenter.playCommand.isEnabled = false
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.isEnabled = false

    // Remove all existing targets
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.pauseCommand.removeTarget(nil)
    commandCenter.togglePlayPauseCommand.removeTarget(nil)

    // Note: iOS doesn't allow apps to intercept long-press for Siri
    // Long-press will still trigger Siri due to system-level handling
    // Users should use single-press in toggle mode as workaround

    // Now enable only the commands we want with higher priority
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    
    // Handle toggle play/pause command (most common for headset buttons)
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
      print("Toggle play/pause command received - this is our primary handler!")
      self?.handlePTTButtonEvent(channel: channel)
      return .success
    }
    
    // Handle play command as backup
    commandCenter.playCommand.addTarget { [weak self] event in
      print("Play command received as backup")
      self?.handlePTTButtonEvent(channel: channel)
      return .success
    }
    
    // Handle pause command as backup
    commandCenter.pauseCommand.addTarget { [weak self] event in
      print("Pause command received as backup")
      self?.handlePTTButtonEvent(channel: channel)
      return .success
    }
    
    // Set more aggressive now playing info to establish media control priority
    let nowPlayingInfo: [String: Any] = [
      MPMediaItemPropertyTitle: "Peloton PTT Active",
      MPMediaItemPropertyArtist: "Push-to-Talk Ready",
      MPMediaItemPropertyAlbumTitle: "Peloton Communicator",
      MPMediaItemPropertyPlaybackDuration: NSNumber(value: 999999),
      MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: 0),
      MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: 1.0),
      MPMediaItemPropertyMediaType: NSNumber(value: MPMediaType.anyAudio.rawValue)
    ]
    
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    
    print("Remote command center setup complete with aggressive configuration")
  }
  
  private func handlePTTButtonEvent(channel: FlutterMethodChannel) {
    let currentTime = Date().timeIntervalSince1970
    
    switch pttMode {
    case "toggle":
      // Prevent accidental double press
      if currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL {
        print("Button press ignored - too soon after last press")
        return
      }
      
      lastPressTime = currentTime
      
      // Toggle recording state
      isRecording = !isRecording
      
      if isRecording {
        print("Starting recording (toggle mode)")
        channel.invokeMethod("pttPressed", arguments: nil)
      } else {
        print("Stopping recording (toggle mode)")
        channel.invokeMethod("pttReleased", arguments: nil)
      }
      
    case "hold":
      // For hold mode on iOS, we treat each button press as a toggle
      // since we don't get separate press/release events from the remote control
      if !isRecording {
        // Prevent accidental double press
        if currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL {
          print("Button press ignored - too soon after last press")
          return
        }
        
        lastPressTime = currentTime
        isRecording = true
        print("Starting recording (hold mode - simulated)")
        channel.invokeMethod("pttPressed", arguments: nil)
      } else {
        isRecording = false
        print("Stopping recording (hold mode - simulated)")
        channel.invokeMethod("pttReleased", arguments: nil)
      }
      
    default:
      break
    }
  }
  
  private func handlePTTEvent(isPressed: Bool, channel: FlutterMethodChannel) {
    if isPressed {
      print("PTT pressed")
      channel.invokeMethod("pttPressed", arguments: nil)
    } else {
      print("PTT released")
      channel.invokeMethod("pttReleased", arguments: nil)
    }
  }

  private func configureButtonListeners(button: String, channel: FlutterMethodChannel) {
    // Clean up existing volume button observer
    volumeButtonObserver?.stopObserving()
    volumeButtonObserver = nil

    switch button {
    case "volumeDown", "volumeUp":
      // Setup volume button observer
      volumeButtonObserver = VolumeButtonObserver(
        targetButton: button,
        onPress: { [weak self] in
          self?.handlePTTButtonEvent(channel: channel)
        }
      )
      volumeButtonObserver?.startObserving()
      print("Volume button observer configured for: \(button)")
    case "headsetNext":
      // Already handled by MPRemoteCommandCenter
      print("Headset next track button configured")
    case "headsetPrevious":
      // Already handled by MPRemoteCommandCenter
      print("Headset previous track button configured")
    case "headsetPlayPause":
      // Already handled by MPRemoteCommandCenter
      print("Headset play/pause button configured")
    case "systemPTT":
      // Handled via PTChannelManager once Flutter calls joinPTTChannel.
      // Disable MPRemoteCommandCenter targets so we don't double-fire on headset taps.
      let cc = MPRemoteCommandCenter.shared()
      cc.togglePlayPauseCommand.isEnabled = false
      cc.playCommand.isEnabled = false
      cc.pauseCommand.isEnabled = false
      print("System PTT selected — accessory events will route through PushToTalk framework")
    default:
      print("Button type \(button) uses default configuration")
    }
  }
}

// Volume Button Observer for iOS
class VolumeButtonObserver {
  private let targetButton: String
  private let onPress: () -> Void
  private var audioSession: AVAudioSession?
  private var initialVolume: Float = 0.5
  private var isObserving = false

  init(targetButton: String, onPress: @escaping () -> Void) {
    self.targetButton = targetButton
    self.onPress = onPress
  }

  func startObserving() {
    guard !isObserving else { return }

    do {
      audioSession = AVAudioSession.sharedInstance()

      // Store initial volume
      initialVolume = audioSession?.outputVolume ?? 0.5

      // Configure audio session to allow volume observation
      try audioSession?.setCategory(.ambient, options: [.mixWithOthers])
      try audioSession?.setActive(true)

      // Observe volume changes
      audioSession?.addObserver(
        self,
        forKeyPath: "outputVolume",
        options: [.new, .old],
        context: nil
      )

      isObserving = true
      print("Volume button observer started for: \(targetButton)")
    } catch {
      print("Failed to setup volume button observer: \(error)")
    }
  }

  func stopObserving() {
    guard isObserving else { return }

    audioSession?.removeObserver(self, forKeyPath: "outputVolume")
    isObserving = false
    print("Volume button observer stopped")
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey : Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "outputVolume" {
      guard let newValue = change?[.newKey] as? Float,
            let oldValue = change?[.oldKey] as? Float else { return }

      let volumeChanged = abs(newValue - oldValue) > 0.001

      if volumeChanged {
        let isVolumeUp = newValue > oldValue
        let matchesTarget = (isVolumeUp && targetButton == "volumeUp") ||
                           (!isVolumeUp && targetButton == "volumeDown")

        if matchesTarget {
          print("Volume button pressed: \(targetButton)")
          onPress()

          // Reset volume to prevent actual volume change
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let initialVol = self?.initialVolume {
              let volumeView = MPVolumeView(frame: .zero)
              if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = initialVol
              }
            }
          }
        }
      }
    }
  }

  deinit {
    stopObserving()
  }
}
