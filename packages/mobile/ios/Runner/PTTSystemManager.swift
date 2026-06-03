import Foundation
import Flutter
import AVFoundation
#if canImport(PushToTalk)
import PushToTalk
#endif

@available(iOS 16.0, *)
final class PTTSystemManager: NSObject {
  private let channel: FlutterMethodChannel
  #if canImport(PushToTalk)
  private var channelManager: PTChannelManager?
  private var activeChannelUUID: UUID?
  private var activeChannelName: String = "Peloton PTT"
  #endif

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  func joinChannel(name: String, uuidString: String?, result: @escaping FlutterResult) {
    #if canImport(PushToTalk)
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "UNSUPPORTED_OS", message: "PushToTalk requires iOS 16+", details: nil))
      return
    }
    activeChannelName = name
    let uuid = uuidString.flatMap(UUID.init(uuidString:)) ?? UUID()
    activeChannelUUID = uuid

    let join: () -> Void = { [weak self] in
      guard let self, let manager = self.channelManager else {
        result(FlutterError(code: "NO_MANAGER", message: "Channel manager not ready", details: nil))
        return
      }
      let descriptor = PTChannelDescriptor(name: name, image: nil)
      manager.requestJoinChannel(channelUUID: uuid, descriptor: descriptor) { error in
        if let error {
          result(FlutterError(code: "JOIN_FAILED", message: error.localizedDescription, details: nil))
        } else {
          manager.setAccessoryButtonEventsEnabled(true, channelUUID: uuid) { err in
            if let err { NSLog("PTT accessory enable failed: \(err.localizedDescription)") }
          }
          result(nil)
        }
      }
    }

    if channelManager == nil {
      PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { [weak self] manager, error in
        if let error {
          result(FlutterError(code: "MANAGER_INIT_FAILED", message: error.localizedDescription, details: nil))
          return
        }
        self?.channelManager = manager
        join()
      }
    } else {
      join()
    }
    #else
    result(FlutterError(code: "PTT_UNAVAILABLE", message: "PushToTalk framework not available in SDK", details: nil))
    #endif
  }

  func leaveChannel(result: @escaping FlutterResult) {
    #if canImport(PushToTalk)
    guard let manager = channelManager, let uuid = activeChannelUUID else {
      result(nil)
      return
    }
    manager.leaveChannel(channelUUID: uuid) { error in
      if let error {
        result(FlutterError(code: "LEAVE_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
    activeChannelUUID = nil
    #else
    result(nil)
    #endif
  }

  func beginTransmitting(result: @escaping FlutterResult) {
    #if canImport(PushToTalk)
    guard let manager = channelManager, let uuid = activeChannelUUID else {
      result(FlutterError(code: "NO_CHANNEL", message: "No active PTT channel", details: nil))
      return
    }
    manager.requestBeginTransmitting(channelUUID: uuid) { error in
      if let error {
        result(FlutterError(code: "TX_BEGIN_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
    #else
    result(nil)
    #endif
  }

  func stopTransmitting(result: @escaping FlutterResult) {
    #if canImport(PushToTalk)
    guard let manager = channelManager, let uuid = activeChannelUUID else {
      result(nil)
      return
    }
    manager.stopTransmitting(channelUUID: uuid)
    result(nil)
    #else
    result(nil)
    #endif
  }
}

#if canImport(PushToTalk)
@available(iOS 16.0, *)
extension PTTSystemManager: PTChannelManagerDelegate {
  func channelManager(_ channelManager: PTChannelManager,
                      receivedEphemeralPushToken pushToken: Data) {
    let hex = pushToken.map { String(format: "%02x", $0) }.joined()
    NSLog("PTT ephemeral push token: \(hex)")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      didJoinChannel channelUUID: UUID,
                      reason: PTChannelJoinReason) {
    NSLog("PTT joined channel \(channelUUID) reason=\(reason.rawValue)")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      didLeaveChannel channelUUID: UUID,
                      reason: PTChannelLeaveReason) {
    NSLog("PTT left channel \(channelUUID) reason=\(reason.rawValue)")
  }

  // Hardware / accessory button → begin transmitting
  func channelManager(_ channelManager: PTChannelManager,
                      channelUUID: UUID,
                      didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
    NSLog("PTT didBeginTransmitting source=\(source.rawValue)")
    channel.invokeMethod("pttPressed", arguments: ["source": "systemPTT"])
  }

  func channelManager(_ channelManager: PTChannelManager,
                      channelUUID: UUID,
                      didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
    NSLog("PTT didEndTransmitting source=\(source.rawValue)")
    channel.invokeMethod("pttReleased", arguments: ["source": "systemPTT"])
  }

  func channelManager(_ channelManager: PTChannelManager,
                      didActivate audioSession: AVAudioSession) {
    NSLog("PTT audio session activated")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      didDeactivate audioSession: AVAudioSession) {
    NSLog("PTT audio session deactivated")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      failedToJoinChannel channelUUID: UUID,
                      error: Error) {
    NSLog("PTT failed to join: \(error.localizedDescription)")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      failedToLeaveChannel channelUUID: UUID,
                      error: Error) {
    NSLog("PTT failed to leave: \(error.localizedDescription)")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      failedToBeginTransmittingInChannel channelUUID: UUID,
                      error: Error) {
    NSLog("PTT failed to begin transmitting: \(error.localizedDescription)")
  }

  func channelManager(_ channelManager: PTChannelManager,
                      failedToStopTransmittingInChannel channelUUID: UUID,
                      error: Error) {
    NSLog("PTT failed to stop transmitting: \(error.localizedDescription)")
  }
}

@available(iOS 16.0, *)
extension PTTSystemManager: PTChannelRestorationDelegate {
  func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
    return PTChannelDescriptor(name: activeChannelName, image: nil)
  }
}
#endif
