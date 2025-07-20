import UIKit
import Flutter
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.peloton/ptt"
  private var pttMode = "toggle" // Current PTT mode (toggle or hold)
  private var isRecording = false
  private var lastPressTime = 0.0
  private let DOUBLE_PRESS_INTERVAL = 0.3 // 300ms to prevent accidental double press
  
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    setupAudioSession()
    setupRemoteCommandCenter(channel: pttChannel)
    
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
}
