import Flutter
import UIKit
import AVFoundation
import Speech
import UserNotifications
import Photos

/// 原生iOS权限插件
/// 使用原生iOS API处理权限请求
public class NativeIOSPermissionPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "native_ios_permissions", binaryMessenger: registrar.messenger())
        let instance = NativeIOSPermissionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestMicrophonePermission":
            requestMicrophonePermission(result: result)
        case "requestSpeechRecognitionPermission":
            requestSpeechRecognitionPermission(result: result)
        case "requestNotificationPermission":
            requestNotificationPermission(result: result)
        case "requestCameraPermission":
            requestCameraPermission(result: result)
        case "requestPhotoLibraryPermission":
            requestPhotoLibraryPermission(result: result)
        case "checkMicrophonePermissionStatus":
            checkMicrophonePermissionStatus(result: result)
        case "checkSpeechRecognitionPermissionStatus":
            checkSpeechRecognitionPermissionStatus(result: result)
        case "checkNotificationPermissionStatus":
            checkNotificationPermissionStatus(result: result)
        case "openAppSettings":
            openAppSettings(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 麦克风权限
    
    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            print("🎤 [NativeIOSPermissionPlugin] 麦克风权限已授予")
            result(true)
        case .denied:
            print("🎤 [NativeIOSPermissionPlugin] 麦克风权限被拒绝")
            result(false)
        case .undetermined:
            print("🎤 [NativeIOSPermissionPlugin] 请求麦克风权限...")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print("🎤 [NativeIOSPermissionPlugin] 麦克风权限请求结果: \(granted)")
                    result(granted)
                }
            }
        @unknown default:
            print("🎤 [NativeIOSPermissionPlugin] 未知麦克风权限状态")
            result(false)
        }
    }
    
    private func checkMicrophonePermissionStatus(result: @escaping FlutterResult) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            result("granted")
        case .denied:
            result("denied")
        case .undetermined:
            result("undetermined")
        @unknown default:
            result("denied")
        }
    }
    
    // MARK: - 语音识别权限
    
    private func requestSpeechRecognitionPermission(result: @escaping FlutterResult) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            print("🗣️ [NativeIOSPermissionPlugin] 语音识别权限已授予")
            result(true)
        case .denied, .restricted:
            print("🗣️ [NativeIOSPermissionPlugin] 语音识别权限被拒绝")
            result(false)
        case .notDetermined:
            print("🗣️ [NativeIOSPermissionPlugin] 请求语音识别权限...")
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let granted = status == .authorized
                    print("🗣️ [NativeIOSPermissionPlugin] 语音识别权限请求结果: \(granted)")
                    result(granted)
                }
            }
        @unknown default:
            print("🗣️ [NativeIOSPermissionPlugin] 未知语音识别权限状态")
            result(false)
        }
    }
    
    private func checkSpeechRecognitionPermissionStatus(result: @escaping FlutterResult) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            result("granted")
        case .denied, .restricted:
            result("denied")
        case .notDetermined:
            result("undetermined")
        @unknown default:
            result("denied")
        }
    }
    
    // MARK: - 通知权限
    
    private func requestNotificationPermission(result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    print("🔔 [NativeIOSPermissionPlugin] 通知权限已授予")
                    result(true)
                case .denied:
                    print("🔔 [NativeIOSPermissionPlugin] 通知权限被拒绝")
                    result(false)
                case .notDetermined:
                    print("🔔 [NativeIOSPermissionPlugin] 请求通知权限...")
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("🔔 [NativeIOSPermissionPlugin] 通知权限请求错误: \(error)")
                                result(false)
                            } else {
                                print("🔔 [NativeIOSPermissionPlugin] 通知权限请求结果: \(granted)")
                                result(granted)
                            }
                        }
                    }
                @unknown default:
                    print("🔔 [NativeIOSPermissionPlugin] 未知通知权限状态")
                    result(false)
                }
            }
        }
    }
    
    private func checkNotificationPermissionStatus(result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    result("granted")
                case .denied:
                    result("denied")
                case .notDetermined:
                    result("undetermined")
                @unknown default:
                    result("denied")
                }
            }
        }
    }
    
    // MARK: - 相机权限
    
    private func requestCameraPermission(result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("📷 [NativeIOSPermissionPlugin] 相机权限已授予")
            result(true)
        case .denied, .restricted:
            print("📷 [NativeIOSPermissionPlugin] 相机权限被拒绝")
            result(false)
        case .notDetermined:
            print("📷 [NativeIOSPermissionPlugin] 请求相机权限...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("📷 [NativeIOSPermissionPlugin] 相机权限请求结果: \(granted)")
                    result(granted)
                }
            }
        @unknown default:
            print("📷 [NativeIOSPermissionPlugin] 未知相机权限状态")
            result(false)
        }
    }
    
    // MARK: - 相册权限
    
    private func requestPhotoLibraryPermission(result: @escaping FlutterResult) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            print("📱 [NativeIOSPermissionPlugin] 相册权限已授予")
            result(true)
        case .denied, .restricted:
            print("📱 [NativeIOSPermissionPlugin] 相册权限被拒绝")
            result(false)
        case .notDetermined:
            print("📱 [NativeIOSPermissionPlugin] 请求相册权限...")
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    let granted = status == .authorized
                    print("📱 [NativeIOSPermissionPlugin] 相册权限请求结果: \(granted)")
                    result(granted)
                }
            }
        default:
            // 处理iOS 14+的.limited状态
            if #available(iOS 14, *) {
                if status.rawValue == 3 { // .limited的rawValue是3
                    print("📱 [NativeIOSPermissionPlugin] 相册权限已授予(限制访问)")
                    result(true)
                } else {
                    print("📱 [NativeIOSPermissionPlugin] 未知相册权限状态")
                    result(false)
                }
            } else {
                print("📱 [NativeIOSPermissionPlugin] 未知相册权限状态")
                result(false)
            }
        }
    }
    
    // MARK: - 打开设置
    
    private func openAppSettings(result: @escaping FlutterResult) {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            print("⚙️ [NativeIOSPermissionPlugin] 无法创建设置URL")
            result(false)
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, options: [:]) { success in
                print("⚙️ [NativeIOSPermissionPlugin] 打开设置页面结果: \(success)")
                result(success)
            }
        } else {
            print("⚙️ [NativeIOSPermissionPlugin] 无法打开设置URL")
            result(false)
        }
    }
}
