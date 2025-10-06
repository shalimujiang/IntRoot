import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// iOS权限管理服务
/// 专门处理iOS平台的权限请求和管理
class IOSPermissionService {
  static final IOSPermissionService _instance = IOSPermissionService._internal();
  factory IOSPermissionService() => _instance;
  IOSPermissionService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  /// 检查并请求所有必要的iOS权限
  Future<Map<String, bool>> checkAndRequestAllPermissions() async {
    if (!Platform.isIOS) {
      return {};
    }

    if (kDebugMode) {
      print('🍎 [IOSPermissionService] 开始检查iOS权限');
    }

    final results = <String, bool>{};

    // 1. 麦克风权限（语音识别必需）
    results['microphone'] = await _checkAndRequestMicrophone();
    
    // 2. 语音识别权限
    results['speechRecognition'] = await _checkAndRequestSpeechRecognition();
    
    // 3. 通知权限
    results['notifications'] = await _checkAndRequestNotifications();
    
    // 4. 相机权限
    results['camera'] = await _checkAndRequestCamera();
    
    // 5. 相册权限
    results['photos'] = await _checkAndRequestPhotos();
    
    // 6. 位置权限
    results['location'] = await _checkAndRequestLocation();

    if (kDebugMode) {
      print('🍎 [IOSPermissionService] 权限检查完成:');
      results.forEach((key, value) {
        print('   $key: ${value ? "✅" : "❌"}');
      });
    }

    return results;
  }

  /// 检查并请求麦克风权限
  Future<bool> _checkAndRequestMicrophone() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        if (kDebugMode) {
          print('🍎 麦克风权限被永久拒绝，请到设置中手动开启');
        }
        return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查麦克风权限失败: $e');
      }
      return false;
    }
  }

  /// 检查并请求语音识别权限
  Future<bool> _checkAndRequestSpeechRecognition() async {
    try {
      final status = await Permission.speech.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.speech.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        if (kDebugMode) {
          print('🍎 语音识别权限被永久拒绝，请到设置中手动开启');
        }
        return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查语音识别权限失败: $e');
      }
      return false;
    }
  }

  /// 检查并请求通知权限
  Future<bool> _checkAndRequestNotifications() async {
    try {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        // 先检查当前权限状态
        final currentPermissions = await iosPlugin.checkPermissions();
        
        if (currentPermissions != null) {
          // 如果有任何权限被授予，认为通知权限可用
          return true;
        }

        // 请求权限
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          critical: false,
        );

        return granted == true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查通知权限失败: $e');
      }
      return false;
    }
  }

  /// 检查并请求相机权限
  Future<bool> _checkAndRequestCamera() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查相机权限失败: $e');
      }
      return false;
    }
  }

  /// 检查并请求相册权限
  Future<bool> _checkAndRequestPhotos() async {
    try {
      final status = await Permission.photos.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查相册权限失败: $e');
      }
      return false;
    }
  }

  /// 检查并请求位置权限
  Future<bool> _checkAndRequestLocation() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.locationWhenInUse.request();
        return result.isGranted;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 检查位置权限失败: $e');
      }
      return false;
    }
  }

  /// 显示权限设置指导
  void showPermissionGuide(String permissionType) {
    if (kDebugMode) {
      print('🍎 [IOSPermissionService] $permissionType 权限被拒绝');
      print('请按以下步骤手动开启权限：');
      print('1. 打开 iPhone "设置"');
      print('2. 滚动找到 "InkRoot"');
      print('3. 点击进入应用设置');
      print('4. 开启所需的权限开关');
      print('5. 返回应用重试');
    }
  }

  /// 打开应用设置页面
  Future<void> openAppSettings() async {
    try {
      await Permission.camera.request();
    } catch (e) {
      if (kDebugMode) {
        print('🍎 无法打开应用设置: $e');
      }
    }
  }
}
