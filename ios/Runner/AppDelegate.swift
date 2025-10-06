import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 🔥 模仿Android的pendingNoteId机制
  private var pendingPayload: String?
  private var methodChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 🔔 设置通知中心委托
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // 🔥 关键：设置MethodChannel（和Android MainActivity一样）
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(
      name: "com.didichou.inkroot/native_alarm",
      binaryMessenger: controller.binaryMessenger
    )
    
    // 🔥 监听Flutter的查询请求（和Android getInitialNoteId一样）
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getInitialPayload" {
        print("📱 [AppDelegate] Flutter查询初始payload: \(self?.pendingPayload ?? "nil")")
        result(self?.pendingPayload)
        self?.pendingPayload = nil // 清空避免重复
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("✅ [AppDelegate] MethodChannel已设置")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // 🔔 处理前台通知
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // 🔔 处理通知点击 - 关键！完全模仿Android的handleIntent
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("════════════════════════════════")
    print("🔥 [AppDelegate] 用户点击了通知！")
    
    // 🔥 从notification的userInfo中获取payload
    let userInfo = response.notification.request.content.userInfo
    let payload = userInfo["payload"] as? String ?? userInfo["noteIdString"] as? String
    
    print("📱 [AppDelegate] payload: \(payload ?? "nil")")
    print("📱 [AppDelegate] userInfo: \(userInfo)")
    
    if let payload = payload {
      // 🔥 方式1：立即通过MethodChannel发送（和Android一样）
      if let channel = methodChannel {
        print("📱 [AppDelegate] 尝试通过MethodChannel发送openNote...")
        channel.invokeMethod("openNote", arguments: payload)
        print("✅ [AppDelegate] MethodChannel已调用")
      } else {
        print("⚠️ [AppDelegate] MethodChannel未初始化")
      }
      
      // 🔥 方式2：保存payload等待Flutter查询（和Android的pendingNoteId一样）
      pendingPayload = payload
      print("📱 [AppDelegate] pendingPayload已设置: \(payload)")
    } else {
      print("❌ [AppDelegate] payload为空！")
    }
    
    print("════════════════════════════════")
    
    // 🔥 仍然调用父类方法，让flutter_local_notifications也处理
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
