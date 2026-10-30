import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if let payload = response.notification.request.content.userInfo["circle_payload"] as? String {
      CirclePushBridge.receive(payload); completionHandler(); return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler(notification.request.content.userInfo["circle_payload"] != nil ? [.alert, .sound] : [])
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CirclePushBridge") { CirclePushBridge.register(with: registrar) }
  }
}

/// Local alerts are emitted only after Dart revalidates the authenticated scope.
final class CirclePushBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  static var shared: CirclePushBridge?
  private static var coldPayload: String?
  static func receive(_ payload: String) {
    if let bridge = shared { bridge.record(payload) } else { coldPayload = payload }
  }
  private static let mutex = NSLock()
  private static var lease: String?
  private static var scope = ""
  private var sink: FlutterEventSink?
  private let defaults = UserDefaults.standard
  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = CirclePushBridge(); shared = bridge
    if let payload = coldPayload { coldPayload = nil; bridge.record(payload) }
    registrar.addMethodCallDelegate(bridge, channel: FlutterMethodChannel(name: "circle/push_native", binaryMessenger: registrar.messenger()))
    FlutterEventChannel(name: "circle/push_taps", binaryMessenger: registrar.messenger()).setStreamHandler(bridge)
  }
  func record(_ payload: String) {
    guard payload.utf8.count <= 4096, let bytes = payload.data(using: .utf8),
      let data = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return }
    let id = UUID().uuidString
    guard let encoded = try? JSONSerialization.data(withJSONObject: ["circle_native_tap": ["id": id, "data": data]]),
      let text = String(data: encoded, encoding: .utf8) else { return }
    var pending = defaults.dictionary(forKey: "circle.push.pending") as? [String: String] ?? [:]
    if pending.count >= 32 { pending.removeAll() }
    pending[id] = text; defaults.set(pending, forKey: "circle.push.pending"); sink?(text)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "lock":
      Self.mutex.lock(); defer { Self.mutex.unlock() }
      if Self.lease != nil { result(nil) } else { Self.lease = UUID().uuidString; result(Self.lease) }
    case "unlock":
      Self.mutex.lock(); defer { Self.mutex.unlock() }
      if args["lease"] as? String == Self.lease { Self.lease = nil }; result(nil)
    case "bind":
      Self.mutex.lock()
      let next = args["scope"] as? String ?? "", changed = Self.scope != (args["scope"] as? String ?? "")
      Self.scope = next; Self.mutex.unlock()
      if changed {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
      }; result(nil)
    case "initial": result((defaults.dictionary(forKey: "circle.push.pending") as? [String: String])?.values.first)
    case "ack":
      var pending = defaults.dictionary(forKey: "circle.push.pending") as? [String: String] ?? [:]
      if let id = args["id"] as? String { pending.removeValue(forKey: id) }
      defaults.set(pending, forKey: "circle.push.pending"); result(nil)
    case "show":
      guard let scope = args["scope"] as? String, !scope.isEmpty, let event = args["event"] as? String,
        let expires = args["expires"] as? NSNumber, expires.doubleValue > Date().timeIntervalSince1970,
        let payload = args["payload"] as? String, payload.utf8.count <= 4096 else { result(false); return }
      Self.mutex.lock()
      guard Self.scope == scope else { Self.mutex.unlock(); result(false); return }
      let id = scope + ":" + event
      var history = defaults.dictionary(forKey: "circle.push.displayed") as? [String: Double] ?? [:]
      history = history.filter { $0.value > Date().timeIntervalSince1970 }
      guard history[id] == nil, history.count < 512 else { Self.mutex.unlock(); result(false); return }
      history[id] = expires.doubleValue; defaults.set(history, forKey: "circle.push.displayed"); Self.mutex.unlock()
      let content = UNMutableNotificationContent()
      content.title = "CIRCLE"; content.body = "You have a new update. Open CIRCLE to view it."
      content.sound = .default; content.userInfo = ["circle_payload": payload]
      UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
        DispatchQueue.main.async { result(error == nil) }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
}
