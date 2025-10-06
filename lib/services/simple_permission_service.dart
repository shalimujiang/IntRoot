import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 简化的权限服务
/// 直接使用permission_handler和flutter_local_notifications
class SimplePermissionService {
  static final SimplePermissionService _instance = SimplePermissionService._internal();
  factory SimplePermissionService() => _instance;
  SimplePermissionService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  /// 请求语音识别权限（麦克风 + 语音识别）
  Future<bool> requestSpeechPermissions(BuildContext? context) async {
    if (kDebugMode) {
      print('🎤 [SimplePermissionService] 开始请求语音识别权限');
    }

    try {
      // 1. 先显示权限说明对话框
      if (context != null) {
        final shouldRequest = await _showPermissionDialog(
          context,
          '语音识别权限',
          '语音识别功能需要访问您的麦克风来录制语音并转换为文字。\n\n这将帮助您快速输入笔记内容。',
          '🎤',
        );
        
        if (!shouldRequest) {
          if (kDebugMode) {
            print('🎤 [SimplePermissionService] 用户取消权限请求');
          }
          return false;
        }
      }

      // 2. 请求麦克风权限
      final micStatus = await Permission.microphone.status;
      if (kDebugMode) {
        print('🎤 [SimplePermissionService] 当前麦克风权限状态: $micStatus');
      }

      if (micStatus.isDenied || micStatus.isRestricted) {
        if (kDebugMode) {
          print('🎤 [SimplePermissionService] 请求麦克风权限...');
        }
        
        final micResult = await Permission.microphone.request();
        if (kDebugMode) {
          print('🎤 [SimplePermissionService] 麦克风权限请求结果: $micResult');
        }
        
        if (!micResult.isGranted) {
          if (context != null) {
            await _showSettingsDialog(
              context,
              '麦克风权限被拒绝',
              '语音识别功能需要麦克风权限。请在设置中手动开启麦克风权限。',
            );
          }
          return false;
        }
      }

      // 3. iOS还需要语音识别权限
      if (Platform.isIOS) {
        final speechStatus = await Permission.speech.status;
        if (kDebugMode) {
          print('🗣️ [SimplePermissionService] 当前语音识别权限状态: $speechStatus');
        }

        if (speechStatus.isDenied || speechStatus.isRestricted) {
          if (kDebugMode) {
            print('🗣️ [SimplePermissionService] 请求语音识别权限...');
          }
          
          final speechResult = await Permission.speech.request();
          if (kDebugMode) {
            print('🗣️ [SimplePermissionService] 语音识别权限请求结果: $speechResult');
          }
          
          if (!speechResult.isGranted) {
            if (context != null) {
              await _showSettingsDialog(
                context,
                '语音识别权限被拒绝',
                '语音识别功能需要语音识别权限。请在设置中手动开启语音识别权限。',
              );
            }
            return false;
          }
        }
      }

      if (kDebugMode) {
        print('✅ [SimplePermissionService] 语音识别权限获取成功');
      }
      return true;

    } catch (e) {
      if (kDebugMode) {
        print('❌ [SimplePermissionService] 请求语音识别权限失败: $e');
      }
      return false;
    }
  }

  /// 请求通知权限
  Future<bool> requestNotificationPermissions(BuildContext? context) async {
    if (kDebugMode) {
      print('🔔 [SimplePermissionService] 开始请求通知权限');
    }

    try {
      // 1. 先显示权限说明对话框
      if (context != null) {
        final shouldRequest = await _showPermissionDialog(
          context,
          '通知权限',
          '应用需要通知权限来提醒您重要的笔记和待办事项。\n\n这将帮助您不错过重要的提醒。',
          '🔔',
        );
        
        if (!shouldRequest) {
          if (kDebugMode) {
            print('🔔 [SimplePermissionService] 用户取消通知权限请求');
          }
          return false;
        }
      }

      // 2. iOS使用flutter_local_notifications请求权限
      if (Platform.isIOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        
        if (iosPlugin != null) {
          // 先检查当前权限状态
          final currentPermissions = await iosPlugin.checkPermissions();
          if (kDebugMode) {
            print('🔔 [SimplePermissionService] 当前iOS通知权限状态: $currentPermissions');
          }
          
          // 如果已经有权限，直接返回成功
          if (currentPermissions != null) {
            if (kDebugMode) {
              print('✅ [SimplePermissionService] iOS通知权限已存在');
            }
            return true;
          }

          // 请求权限
          if (kDebugMode) {
            print('🔔 [SimplePermissionService] 请求iOS通知权限...');
          }
          
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
            critical: false,
          );

          if (kDebugMode) {
            print('🔔 [SimplePermissionService] iOS通知权限请求结果: $granted');
          }

          if (granted != true) {
            if (context != null) {
              await _showSettingsDialog(
                context,
                '通知权限被拒绝',
                '通知功能需要通知权限。请在设置中手动开启通知权限。',
              );
            }
            return false;
          }

          if (kDebugMode) {
            print('✅ [SimplePermissionService] iOS通知权限获取成功');
          }
          return true;
        }
      } else {
        // Android使用permission_handler
        final notificationStatus = await Permission.notification.status;
        if (kDebugMode) {
          print('🔔 [SimplePermissionService] 当前Android通知权限状态: $notificationStatus');
        }

        if (notificationStatus.isDenied || notificationStatus.isRestricted) {
          if (kDebugMode) {
            print('🔔 [SimplePermissionService] 请求Android通知权限...');
          }
          
          final notificationResult = await Permission.notification.request();
          if (kDebugMode) {
            print('🔔 [SimplePermissionService] Android通知权限请求结果: $notificationResult');
          }
          
          if (!notificationResult.isGranted) {
            if (context != null) {
              await _showSettingsDialog(
                context,
                '通知权限被拒绝',
                '通知功能需要通知权限。请在设置中手动开启通知权限。',
              );
            }
            return false;
          }
        }

        if (kDebugMode) {
          print('✅ [SimplePermissionService] Android通知权限获取成功');
        }
        return true;
      }

      return false;

    } catch (e) {
      if (kDebugMode) {
        print('❌ [SimplePermissionService] 请求通知权限失败: $e');
      }
      return false;
    }
  }

  /// 显示权限请求对话框
  Future<bool> _showPermissionDialog(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 提示：授权后可以正常使用相关功能',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不授权'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('立即授权'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 显示设置引导对话框
  Future<void> _showSettingsDialog(
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '操作步骤：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 点击"去设置"按钮\n2. 找到相应权限开关\n3. 开启权限后返回应用\n4. 重新尝试使用功能',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
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
}
