import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// iOS通知调试服务
/// 用于诊断通知为什么不显示
class NotificationDebugService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  /// 全面检查通知配置
  static Future<Map<String, dynamic>> diagnoseNotifications() async {
    final result = <String, dynamic>{};
    
    print('\n═══════════════════════════════════════');
    print('🔍 开始诊断iOS通知问题');
    print('═══════════════════════════════════════\n');

    if (!Platform.isIOS) {
      result['error'] = '此诊断仅适用于iOS';
      return result;
    }

    // 1. 检查权限状态
    print('📋 [1/6] 检查通知权限...');
    try {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final permissions = await iosPlugin.checkPermissions();
        result['permissions'] = permissions?.toString() ?? 'null';
        
        if (permissions == null) {
          print('   ❌ 权限未授予或未请求');
          result['permissionGranted'] = false;
        } else {
          print('   ✅ 权限已授予: $permissions');
          result['permissionGranted'] = true;
        }
      } else {
        print('   ❌ 无法获取iOS通知插件实例');
        result['iosPluginAvailable'] = false;
      }
    } catch (e) {
      print('   ❌ 检查权限失败: $e');
      result['permissionError'] = e.toString();
    }

    // 2. 检查时区设置
    print('\n📋 [2/6] 检查时区设置...');
    try {
      final localTz = tz.local;
      final now = DateTime.now();
      final tzNow = tz.TZDateTime.now(localTz);
      
      result['timezone'] = localTz.name;
      result['deviceTime'] = now.toString();
      result['tzTime'] = tzNow.toString();
      result['timezoneOffset'] = now.timeZoneOffset.inHours;
      
      print('   时区名称: ${localTz.name}');
      print('   设备时间: $now');
      print('   TZ时间: $tzNow');
      print('   时区偏移: UTC${now.timeZoneOffset.inHours >= 0 ? '+' : ''}${now.timeZoneOffset.inHours}');
      
      // 检查时区是否一致
      final diff = now.difference(tzNow.toLocal()).abs();
      if (diff.inSeconds > 5) {
        print('   ⚠️ 警告：时区时间差异过大（${diff.inSeconds}秒）');
        result['timezoneWarning'] = '时区可能配置不正确';
      } else {
        print('   ✅ 时区配置正确');
      }
    } catch (e) {
      print('   ❌ 检查时区失败: $e');
      result['timezoneError'] = e.toString();
    }

    // 3. 检查待发送的通知
    print('\n📋 [3/6] 检查待发送通知队列...');
    try {
      final pending = await _notifications.pendingNotificationRequests();
      result['pendingCount'] = pending.length;
      result['pendingNotifications'] = pending.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
      }).toList();
      
      print('   待发送通知数量: ${pending.length}');
      if (pending.isEmpty) {
        print('   ⚠️ 警告：没有待发送的通知！');
        print('   提示：如果你刚设置了提醒但队列是空的，说明通知没有被成功调度');
      } else {
        print('   ✅ 通知队列正常');
        for (var notification in pending) {
          print('      - ID: ${notification.id}, 标题: ${notification.title}');
        }
      }
    } catch (e) {
      print('   ❌ 检查队列失败: $e');
      result['queueError'] = e.toString();
    }

    // 4. 测试立即通知
    print('\n📋 [4/6] 测试立即通知...');
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        '测试通知',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.show(
        999999,
        '🔔 通知测试',
        '如果你看到这条通知，说明基础通知功能正常',
        details,
      );
      
      print('   ✅ 已发送测试通知（ID: 999999）');
      print('   提示：如果你看到了通知，说明权限和配置是正常的');
      result['immediateNotificationSent'] = true;
    } catch (e) {
      print('   ❌ 发送测试通知失败: $e');
      result['immediateNotificationError'] = e.toString();
    }

    // 5. 测试5秒后的调度通知
    print('\n📋 [5/6] 测试调度通知（5秒后）...');
    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        '测试通知',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.zonedSchedule(
        999998,
        '⏰ 调度通知测试',
        '如果你看到这条通知，说明调度功能正常',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      print('   ✅ 已调度测试通知（5秒后）');
      print('   调度时间: $scheduledTime');
      print('   提示：请等待5秒，看是否收到通知');
      result['scheduledNotificationSet'] = true;
      result['scheduledTime'] = scheduledTime.toString();
    } catch (e) {
      print('   ❌ 调度测试通知失败: $e');
      result['scheduledNotificationError'] = e.toString();
    }

    // 6. 验证调度是否成功
    print('\n📋 [6/6] 验证测试通知是否在队列中...');
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final testNotification = pending.where((n) => n.id == 999998).firstOrNull;
      
      if (testNotification != null) {
        print('   ✅ 测试通知在队列中');
        result['testNotificationInQueue'] = true;
      } else {
        print('   ❌ 警告：测试通知不在队列中！');
        print('   这表明zonedSchedule调用可能失败了');
        result['testNotificationInQueue'] = false;
      }
    } catch (e) {
      print('   ❌ 验证失败: $e');
      result['verificationError'] = e.toString();
    }

    print('\n═══════════════════════════════════════');
    print('🔍 诊断完成');
    print('═══════════════════════════════════════\n');

    return result;
  }

  /// 清理测试通知
  static Future<void> cleanupTestNotifications() async {
    try {
      await _notifications.cancel(999999);
      await _notifications.cancel(999998);
      if (kDebugMode) {
        print('✅ 测试通知已清理');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 清理测试通知失败: $e');
      }
    }
  }
}

