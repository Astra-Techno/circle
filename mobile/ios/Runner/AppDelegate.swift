import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging
import ContactsUI
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Explicitly bridge the Apple token even with the implicit Flutter engine.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if let payload = response.notification.request.content.userInfo["circle_payload"] as? String {
      CirclePushBridge.receive(payload); completionHandler(); return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.content.userInfo["circle_payload"] != nil {
      completionHandler([.alert, .sound]); return
    }
    // Forward to FlutterFire so onMessage is emitted, but let Dart authorize
    // before showing a local notification instead of automatic remote display.
    super.userNotificationCenter(center, willPresent: notification) { _ in completionHandler([]) }
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CircleInviteShare") { CircleInviteShare.register(with: registrar) }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CirclePhotoExport") { CirclePhotoExport.register(with: registrar) }
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
  private static func notificationBody(_ type: String) -> String {
    switch type {
    case "memory.created": return "Someone shared a new Memory in your circle."
    case "comment.created": return "Someone commented on your Memory."
    case "comment.reply": return "Someone commented on your Memory."
    case "group.invitation": return "You have a new circle invitation."
    case "group.report": return "A group report needs attention."
    case "chat.message": return "You have a new chat message."
    case "poll.created": return "A new poll is available in your circle."
    case "poll.closed": return "A poll in your circle has closed."
    case "event.created": return "A new event was added in your circle."
    case "event.updated": return "An event in your circle was updated"
    case "event.cancelled": return "An event in your circle was cancelled."
    case "event.rsvp": return "Someone responded to your event."
    case "event.reminder": return "Your event is starting soon."
    case "scope": return "https://www.googleapis.com/auth/firebase.messaging"
    case "grant_type": return "urn:ietf:params:oauth:grant-type:jwt-bearer"
    default: return "You have a new update. Open CIRCLE to view it."
    }
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "registerAPNS":
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      }
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
      let preview = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any]
      content.title = (preview?["notification_title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "CIRCLE"
      content.body = (preview?["notification_body"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.notificationBody(preview?["type"] as? String ?? "")
      content.sound = .default; content.userInfo = ["circle_payload": payload]
      UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
        DispatchQueue.main.async {
          if error != nil {
            Self.mutex.lock()
            var saved = self.defaults.dictionary(forKey: "circle.push.displayed") as? [String: Double] ?? [:]
            saved.removeValue(forKey: id)
            self.defaults.set(saved, forKey: "circle.push.displayed")
            Self.mutex.unlock()
          }
          result(error == nil)
        }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
}


/// System-owned one-number picker. No CNContactStore access or address-book upload.
final class CircleInviteShare: NSObject, FlutterPlugin, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {
  private static var shared: CircleInviteShare?
  private let registrar: FlutterPluginRegistrar
  private var pickerResult: FlutterResult?
  init(_ registrar: FlutterPluginRegistrar) { self.registrar = registrar; super.init() }
  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = CircleInviteShare(registrar); shared = bridge
    registrar.addMethodCallDelegate(bridge, channel: FlutterMethodChannel(name: "circle/invite_share", binaryMessenger: registrar.messenger()))
  }
  private var presenter: UIViewController? {
    var root = registrar.viewController
    while let presented = root?.presentedViewController { root = presented }
    return root
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let view = presenter else { result(FlutterError(code: "unavailable", message: "Open the invitation again.", details: nil)); return }
    switch call.method {
    case "pickPhone":
      guard pickerResult == nil else { result(FlutterError(code: "busy", message: "Finish selecting a contact.", details: nil)); return }
      pickerResult = result
      let picker = CNContactPickerViewController()
      picker.delegate = self
      picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
      picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
      picker.predicateForSelectionOfContact = NSPredicate(value: false)
      picker.predicateForSelectionOfProperty = NSPredicate(format: "key == %@", CNContactPhoneNumbersKey)
      view.present(picker, animated: true)
    case "compose":
      let args = call.arguments as? [String: Any] ?? [:]
      guard let text = args["text"] as? String, text.utf8.count <= 4096 else { result(false); return }
      let target = args["target"] as? String ?? "other"
      if target == "sms" {
        guard MFMessageComposeViewController.canSendText() else { result(false); return }
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.body = text
        if let phone = args["phone"] as? String { composer.recipients = [phone] }
        view.present(composer, animated: true)
        result(true)
      } else if target == "whatsapp" {
        var parts = URLComponents(); parts.scheme = "whatsapp"; parts.host = "send"
        parts.queryItems = [URLQueryItem(name: "text", value: text)]
        guard let url = parts.url else { result(false); return }
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      } else {
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.view.bounds.midX, y: view.view.bounds.midY, width: 1, height: 1)
        view.present(sheet, animated: true)
        result(true)
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    let result = pickerResult; pickerResult = nil
    // CNContactPickerViewController dismisses itself on cancel/selection.
    result?(nil)
  }
  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    let result = pickerResult; pickerResult = nil
    let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue
    result?(phone)
  }
  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    controller.dismiss(animated: true)
  }
}


/// System-owned image share/save sheet. The temporary file is removed when
/// the sheet finishes; Download lets the person choose Save Image or Files.
final class CirclePhotoExport: NSObject, FlutterPlugin {
  private static var shared: CirclePhotoExport?
  private let registrar: FlutterPluginRegistrar
  private var exporting = false
  private let maxBytes = 32 * 1024 * 1024

  init(_ registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = CirclePhotoExport(registrar)
    shared = bridge
    registrar.addMethodCallDelegate(bridge, channel: FlutterMethodChannel(name: "circle/photo_export", binaryMessenger: registrar.messenger()))
  }

  private var presenter: UIViewController? {
    var root = registrar.viewController
    while let presented = root?.presentedViewController { root = presented }
    return root
  }

  private func valid(_ name: String, _ mime: String) -> Bool {
    (name == "circle-photo.jpg" && mime == "image/jpeg") ||
      (name == "circle-photo.png" && mime == "image/png") ||
      (name == "circle-photo.webp" && mime == "image/webp")
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    guard !exporting else {
      result(FlutterError(code: "busy", message: "Finish the current photo action first.", details: nil)); return
    }
    guard let view = presenter else {
      result(FlutterError(code: "unavailable", message: "Open the photo again.", details: nil)); return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let action = args["action"] as? String ?? ""
    let name = args["name"] as? String ?? ""
    let mime = args["mime_type"] as? String ?? ""
    guard (action == "share" || action == "download"),
      let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
      !data.isEmpty, data.count <= maxBytes, valid(name, mime) else {
      result(FlutterError(code: "invalid", message: "The photo could not be exported.", details: nil)); return
    }

    exporting = true
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("circle-photo-exports", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let file = directory.appendingPathComponent(name)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try data.write(to: file, options: .atomic)
    } catch {
      exporting = false
      try? FileManager.default.removeItem(at: directory)
      result(FlutterError(code: "unavailable", message: "The photo could not be prepared.", details: nil))
      return
    }

    let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = view.view
    sheet.popoverPresentationController?.sourceRect = CGRect(x: view.view.bounds.midX, y: view.view.bounds.midY, width: 1, height: 1)
    sheet.completionWithItemsHandler = { _, completed, _, error in
      self.exporting = false
      try? FileManager.default.removeItem(at: directory)
      if let error = error {
        result(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
      } else {
        result(completed)
      }
    }
    view.present(sheet, animated: true)
  }
}
