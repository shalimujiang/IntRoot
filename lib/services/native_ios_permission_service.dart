import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// 原生iOS权限服务
/// 使用MethodChannel调用原生iOS权限API
class NativeIOSPermissionService {
  static final NativeIOSPermissionService _instance = NativeIOSPermissionService._internal();
  factory NativeIOSPermissionService() => _instance;
  NativeIOSPermissionService._internal();

  static const MethodChannel _channel = MethodChannel('native_ios_permissions');

  /// 请求麦克风权限（使用原生AVAudioSession）
  Future<bool> requestMicrophonePermission() async {
    if (!Platform.isIOS) return true;

    try {
      final bool granted = await _channel.invokeMethod('requestMicrophonePermission');
      if (kDebugMode) {
        print('🎤 [NativeIOSPermissionService] 麦克风权限结果: $granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('🎤 [NativeIOSPermissionService] 请求麦克风权限失败: $e');
      }
      return false;
    }
  }

  /// 请求语音识别权限（使用原生SFSpeechRecognizer）
  Future<bool> requestSpeechRecognitionPermission() async {
    if (!Platform.isIOS) return true;

    try {
      final bool granted = await _channel.invokeMethod('requestSpeechRecognitionPermission');
      if (kDebugMode) {
        print('🗣️ [NativeIOSPermissionService] 语音识别权限结果: $granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('🗣️ [NativeIOSPermissionService] 请求语音识别权限失败: $e');
      }
      return false;
    }
  }

  /// 请求通知权限（使用原生UNUserNotificationCenter）
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isIOS) return true;

    try {
      final bool granted = await _channel.invokeMethod('requestNotificationPermission');
      if (kDebugMode) {
        print('🔔 [NativeIOSPermissionService] 通知权限结果: $granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 [NativeIOSPermissionService] 请求通知权限失败: $e');
      }
      return false;
    }
  }

  /// 请求相机权限（使用原生AVCaptureDevice）
  Future<bool> requestCameraPermission() async {
    if (!Platform.isIOS) return true;

    try {
      final bool granted = await _channel.invokeMethod('requestCameraPermission');
      if (kDebugMode) {
        print('📷 [NativeIOSPermissionService] 相机权限结果: $granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('📷 [NativeIOSPermissionService] 请求相机权限失败: $e');
      }
      return false;
    }
  }

  /// 请求相册权限（使用原生PHPhotoLibrary）
  Future<bool> requestPhotoLibraryPermission() async {
    if (!Platform.isIOS) return true;

    try {
      final bool granted = await _channel.invokeMethod('requestPhotoLibraryPermission');
      if (kDebugMode) {
        print('📱 [NativeIOSPermissionService] 相册权限结果: $granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('📱 [NativeIOSPermissionService] 请求相册权限失败: $e');
      }
      return false;
    }
  }

  /// 检查麦克风权限状态
  Future<String> checkMicrophonePermissionStatus() async {
    if (!Platform.isIOS) return 'granted';

    try {
      final String status = await _channel.invokeMethod('checkMicrophonePermissionStatus');
      return status; // 'granted', 'denied', 'undetermined'
    } catch (e) {
      if (kDebugMode) {
        print('🎤 [NativeIOSPermissionService] 检查麦克风权限状态失败: $e');
      }
      return 'denied';
    }
  }

  /// 检查语音识别权限状态
  Future<String> checkSpeechRecognitionPermissionStatus() async {
    if (!Platform.isIOS) return 'granted';

    try {
      final String status = await _channel.invokeMethod('checkSpeechRecognitionPermissionStatus');
      return status; // 'granted', 'denied', 'undetermined'
    } catch (e) {
      if (kDebugMode) {
        print('🗣️ [NativeIOSPermissionService] 检查语音识别权限状态失败: $e');
      }
      return 'denied';
    }
  }

  /// 检查通知权限状态
  Future<String> checkNotificationPermissionStatus() async {
    if (!Platform.isIOS) return 'granted';

    try {
      final String status = await _channel.invokeMethod('checkNotificationPermissionStatus');
      return status; // 'granted', 'denied', 'undetermined'
    } catch (e) {
      if (kDebugMode) {
        print('🔔 [NativeIOSPermissionService] 检查通知权限状态失败: $e');
      }
      return 'denied';
    }
  }

  /// 打开应用设置页面
  Future<bool> openAppSettings() async {
    if (!Platform.isIOS) return false;

    try {
      final bool opened = await _channel.invokeMethod('openAppSettings');
      if (kDebugMode) {
        print('⚙️ [NativeIOSPermissionService] 打开设置页面: $opened');
      }
      return opened;
    } catch (e) {
      if (kDebugMode) {
        print('⚙️ [NativeIOSPermissionService] 打开设置页面失败: $e');
      }
      return false;
    }
  }

  /// 显示权限说明对话框
  Future<bool> showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    String emoji,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              const Text(
                '💡 提示：授权后可以正常使用相关功能',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不授权'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('立即授权'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 显示设置引导对话框
  Future<void> showSettingsDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                '操作步骤：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. 点击"去设置"按钮\n2. 在设置页面找到相应权限\n3. 开启权限开关\n4. 返回应用重试',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }

  /// 综合权限请求方法 - 语音识别
  Future<bool> requestSpeechPermissions(BuildContext? context) async {
    if (!Platform.isIOS) return true;

    // 1. 检查麦克风权限
    final micStatus = await checkMicrophonePermissionStatus();
    if (micStatus == 'denied') {
      if (context != null) {
        await showSettingsDialog(
          context,
          '麦克风权限被拒绝',
          '语音识别功能需要麦克风权限，请在设置中手动开启。',
        );
      }
      return false;
    }

    if (micStatus == 'undetermined') {
      if (context != null) {
        final shouldRequest = await showPermissionDialog(
          context,
          '麦克风权限',
          '语音识别功能需要访问麦克风来录制您的语音。',
          '🎤',
        );
        if (!shouldRequest) return false;
      }

      final micGranted = await requestMicrophonePermission();
      if (!micGranted) return false;
    }

    // 2. 检查语音识别权限
    final speechStatus = await checkSpeechRecognitionPermissionStatus();
    if (speechStatus == 'denied') {
      if (context != null) {
        await showSettingsDialog(
          context,
          '语音识别权限被拒绝',
          '语音识别功能需要语音识别权限，请在设置中手动开启。',
        );
      }
      return false;
    }

    if (speechStatus == 'undetermined') {
      if (context != null) {
        final shouldRequest = await showPermissionDialog(
          context,
          '语音识别权限',
          '应用需要语音识别权限来将您的语音转换为文字。',
          '🗣️',
        );
        if (!shouldRequest) return false;
      }

      final speechGranted = await requestSpeechRecognitionPermission();
      if (!speechGranted) return false;
    }

    return true;
  }

  /// 综合权限请求方法 - 通知
  Future<bool> requestNotificationPermissions(BuildContext? context) async {
    if (!Platform.isIOS) return true;

    final status = await checkNotificationPermissionStatus();
    if (status == 'denied') {
      if (context != null) {
        await showSettingsDialog(
          context,
          '通知权限被拒绝',
          '通知功能需要通知权限，请在设置中手动开启。',
        );
      }
      return false;
    }

    if (status == 'undetermined') {
      if (context != null) {
        final shouldRequest = await showPermissionDialog(
          context,
          '通知权限',
          '应用需要通知权限来提醒您重要的笔记和待办事项。',
          '🔔',
        );
        if (!shouldRequest) return false;
      }

      return await requestNotificationPermission();
    }

    return true;
  }
}
