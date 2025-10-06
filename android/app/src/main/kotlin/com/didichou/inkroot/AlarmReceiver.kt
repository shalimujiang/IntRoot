package com.didichou.inkroot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val noteId = intent.getIntExtra("noteId", 0)
        val title = intent.getStringExtra("title") ?: "笔记提醒"
        val body = intent.getStringExtra("body") ?: ""
        
        // 🔥 关键日志：确认AlarmReceiver被触发
        android.util.Log.e("AlarmReceiver", "════════════════════════════════")
        android.util.Log.e("AlarmReceiver", "⏰⏰⏰ 闹钟触发！！！")
        android.util.Log.e("AlarmReceiver", "noteId=$noteId, title=$title, body=$body")
        android.util.Log.e("AlarmReceiver", "当前时间: ${System.currentTimeMillis()}")

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // 🔥 定义channel ID（使用新ID确保设置生效）
        val CHANNEL_ID = "note_reminders_v2"
        
        // 🔥 创建通知渠道（Android 8.0+）
        if (Build.VERSION.SDK_INT >= 26) {
            // 🔥 删除旧channel（如果存在）
            try {
                notificationManager.deleteNotificationChannel("note_reminders")
                android.util.Log.e("AlarmReceiver", "✅ 已删除旧通知渠道")
            } catch (e: Exception) {
                android.util.Log.e("AlarmReceiver", "删除旧渠道失败（可能不存在）: ${e.message}")
            }
            
            // 🔥🔥🔥 创建新的通知渠道（使用MAX重要性-屏幕弹出）
            val channel = NotificationChannel(
                CHANNEL_ID,
                "笔记提醒",
                NotificationManager.IMPORTANCE_HIGH  // 使用HIGH确保横幅显示
            ).apply {
                description = "笔记定时提醒通知"
                
                // 🔥🔥🔥 声音设置（使用ALARM类型）
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .build()
                )
                
                // 🔥🔥🔥 振动设置
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                
                // 🔥 其他设置
                enableLights(true)
                lightColor = 0xFFFF5722.toInt()
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(channel)
            android.util.Log.e("AlarmReceiver", "✅✅✅ 通知渠道已创建：$CHANNEL_ID （IMPORTANCE_HIGH + 横幅显示 + 声音 + 振动）")
        }
        
        // 检查通知权限
        if (Build.VERSION.SDK_INT >= 24) {
            val enabled = notificationManager.areNotificationsEnabled()
            android.util.Log.e("AlarmReceiver", "通知权限状态: ${if (enabled) "✅ 已开启" else "❌ 未开启"}")
            if (!enabled) {
                android.util.Log.e("AlarmReceiver", "❌❌❌ 通知权限未开启，无法显示通知！")
                return
            }
        }

        // 🔥🔥🔥 创建提醒Activity的Intent（用于FullScreenIntent）
        val activityIntent = Intent(context, ReminderActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra("noteId", noteId)
            putExtra("title", title)
            putExtra("body", body)
        }
        
        // 创建PendingIntent用于全屏弹出
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            noteId,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        android.util.Log.e("AlarmReceiver", "✅ 已创建FullScreenIntent PendingIntent")
        
        // 🔥🔥🔥 直接播放系统通知声音和强力振动
        try {
            // 播放系统通知声音（不是闹钟声音）
            val ringtoneUri = android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
            val ringtone = android.media.RingtoneManager.getRingtone(context, ringtoneUri)
            if (ringtone != null) {
                ringtone.play()
                android.util.Log.e("AlarmReceiver", "🔊 系统通知声音播放成功")
                
                // 延迟5秒后停止
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        if (ringtone.isPlaying) {
                            ringtone.stop()
                            android.util.Log.e("AlarmReceiver", "🔊 声音已停止")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("AlarmReceiver", "停止声音失败: ${e.message}")
                    }
                }, 5000)
            }
        } catch (e: Exception) {
            android.util.Log.e("AlarmReceiver", "播放声音失败: ${e.message}")
            e.printStackTrace()
        }
        
        // 🔥🔥🔥 强力振动（加大振动强度）
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            if (vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // 使用更强的振动效果
                    val vibrationEffect = android.os.VibrationEffect.createWaveform(
                        longArrayOf(0, 500, 200, 500, 200, 500), // 振动-停-振动-停-振动
                        -1 // 不重复
                    )
                    vibrator.vibrate(vibrationEffect)
                    android.util.Log.e("AlarmReceiver", "📳 强力振动已触发（Android 8.0+）")
                } else {
                    vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
                    android.util.Log.e("AlarmReceiver", "📳 振动已触发（传统模式）")
                }
            } else {
                android.util.Log.e("AlarmReceiver", "⚠️ 设备不支持振动")
            }
        } catch (e: Exception) {
            android.util.Log.e("AlarmReceiver", "振动失败: ${e.message}")
            e.printStackTrace()
        }
        
            // 🔥🔥🔥 关键：点击通知打开应用（不重启，复用现有Activity）
            val notificationIntent = Intent(context, MainActivity::class.java).apply {
                // 使用SINGLE_TOP避免重启应用，如果应用在后台就直接唤起
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                // 添加action确保onNewIntent能收到
                action = "com.didichou.inkroot.OPEN_NOTE"
                putExtra("noteId", noteId)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                noteId + 10000,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        // 🔥🔥🔥 构建通知（对标微信/滴答清单/系统闹钟）
        val iconResId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        android.util.Log.e("AlarmReceiver", "图标资源ID: $iconResId")
        
        // 🔥🔥🔥 关键：获取系统默认声音URI
        val defaultSoundUri = android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
        android.util.Log.e("AlarmReceiver", "声音URI: $defaultSoundUri")
        
        // 🔥🔥🔥 构建通知（参考大厂：微信、滴答清单）
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(if (iconResId != 0) iconResId else android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            
            // 🔥🔥🔥 最高优先级（必须）
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            
            // 🔥🔥🔥 关键：直接设置声音（不依赖DEFAULT）
            .setSound(defaultSoundUri, android.media.AudioManager.STREAM_ALARM)
            
            // 🔥🔥🔥 关键：直接设置振动
            .setVibrate(longArrayOf(0, 500, 250, 500, 250, 500))
            
            // 🔥 LED灯
            .setLights(0xFFFF5722.toInt(), 1000, 500)
            
            // 🔥 锁屏和heads-up显示
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            
            // 🔥 每次都提醒（不压制）
            .setOnlyAlertOnce(false)
            
            // 🔥 显示时间
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            
            // 🔥 点击后取消
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            
            // 🔥🔥🔥 关键：FullScreenIntent启动Activity（像闹钟那样全屏弹出）
            .setFullScreenIntent(fullScreenPendingIntent, true)
            
            .build()

        // 🔥 显示通知（会自动触发FullScreenIntent）
        try {
            android.util.Log.e("AlarmReceiver", "开始发送通知...")
            android.util.Log.e("AlarmReceiver", "通知ID: $noteId")
            notificationManager.notify(noteId, notification)
            android.util.Log.e("AlarmReceiver", "✅✅✅ 通知已成功发送！")
            android.util.Log.e("AlarmReceiver", "════════════════════════════════")
        } catch (e: Exception) {
            android.util.Log.e("AlarmReceiver", "❌❌❌ 通知发送失败: ${e.message}")
            e.printStackTrace()
            android.util.Log.e("AlarmReceiver", "════════════════════════════════")
        }
    }
}

