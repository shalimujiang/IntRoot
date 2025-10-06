import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/app_provider.dart';
import 'routes/app_router.dart';
import 'themes/app_theme.dart';
import 'utils/image_cache_manager.dart';
// import 'utils/share_helper.dart'; // 🔥 暂时禁用分享接收功能
// import 'services/share_receiver_service.dart'; // 🔥 暂时禁用
import 'services/notification_service.dart';
import 'services/ios_permission_service.dart';
import 'models/app_config_model.dart';
import 'config/app_config.dart' as Config;
import 'dart:io';
import 'package:timeago/timeago.dart' as timeago;

import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 🔥 全局NavigatorKey，用于通知点击跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔥 全局分享接收器（暂时禁用）
// final ShareReceiverService shareReceiverService = ShareReceiverService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化中文日期格式支持
  await initializeDateFormatting('zh_CN', null);
  
  // 初始化timeago库，添加中文支持
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());
  timeago.setDefaultLocale('zh');
  
  // 初始化图片缓存管理器
  await ImageCacheManager.initialize();
  
  // 🔥 权限按需请求策略（模仿微信/支付宝）
  // ✅ 麦克风权限：用户点击语音识别按钮时请求
  // ✅ 通知权限：用户设置提醒时请求
  // ✅ 相机权限：用户点击拍照按钮时请求
  // ✅ 相册权限：用户选择图片时请求
  // ❌ 不在启动时请求任何权限！
  
  // 设置全局的页面转换配置，使所有动画更平滑
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  
  // 创建主应用提供器
  final appProvider = AppProvider();
  
  // 创建路由器（需要在通知服务和 MethodChannel 回调中使用）
  final appRouter = AppRouter(appProvider);
  
  // 🔥 关键：设置全局Router供NotificationService使用
  NotificationService.setGlobalRouter(appRouter.router);
  
  // 🔥 优化启动速度：异步初始化通知服务（不阻塞启动）
  // 微信/支付宝启动时间：0.5-1秒，通知初始化放到后台进行
  appProvider.initializeNotificationService().then((_) {
    print('✅ 通知服务初始化完成（后台）');
  }).catchError((e) {
    print('⚠️ 通知服务初始化失败: $e');
  });
  
  // 🔥 初始化分享接收器（暂时禁用 - 等待修复）
  /*
  final shareHelper = ShareHelper();
  shareReceiverService.initialize(
    onTextShared: (text) {
      print('🔥 收到分享的文本: ${text.length}字');
      shareHelper.setPendingText(text);
    },
    onImagesShared: (imagePaths) {
      print('🔥 收到分享的图片: ${imagePaths.length}张');
      shareHelper.setPendingImages(imagePaths);
    },
    onFilesShared: (filePaths) {
      print('🔥 收到分享的文件: ${filePaths.length}个');
      final fileList = filePaths.map((path) => '📎 ${path.split('/').last}').join('\n');
      shareHelper.setPendingText('分享的文件:\n\n$fileList');
    },
  );
  */
  
  // 🔥 监听来自原生的通知点击和分享事件
  const platform = MethodChannel('com.didichou.inkroot/native_alarm');
  platform.setMethodCallHandler((call) async {
    if (call.method == 'openNote') {
      // 🔥 关键修复：iOS传递的是字符串payload，Android传递的是int hashCode
      final noteIdString = call.arguments is String 
        ? call.arguments as String 
        : (call.arguments is int 
            ? NotificationService.noteIdMapping[call.arguments as int] 
            : null);
      
      print('════════════════════════════════');
      print('🔥 [main.dart] 收到原生通知点击！');
      print('📱 arguments类型: ${call.arguments.runtimeType}');
      print('📱 arguments值: ${call.arguments}');
      print('📱 noteIdString: $noteIdString');
      print('════════════════════════════════');
      
      if (noteIdString == null) {
        print('❌ 无法解析noteId');
        return;
      }
      
      // 等待一小段时间确保应用完全启动
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 🔥 使用GoRouter实例直接导航（不需要context）
      try {
        appRouter.router.go('/note/$noteIdString');
        print('✅ 已跳转到笔记详情页: $noteIdString');
        
        // 🔥 取消该笔记的提醒（通知已查看）
        try {
          final note = appProvider.notes.firstWhere((n) => n.id == noteIdString);
          if (note.reminderTime != null) {
            await appProvider.cancelNoteReminder(noteIdString);
            print('✅ 已取消笔记提醒');
          }
        } catch (e) {
          print('⚠️ 取消提醒失败: $e');
        }
      } catch (e) {
        print('❌ 跳转详情页失败: $e');
      }
    }
    // 🔥 处理分享的文本
    else if (call.method == 'onSharedText') {
      final sharedText = call.arguments as String;
      print('🔥 收到分享的文本: ${sharedText.length}字');
      
      // 等待应用完全启动
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 跳转到主页并打开笔记编辑器（内容预填充）
      appRouter.router.go('/', extra: {'sharedContent': sharedText});
    }
    // 🔥 处理分享的单张图片
    else if (call.method == 'onSharedImage') {
      final imagePath = call.arguments as String;
      print('🔥 收到分享的图片: $imagePath');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 跳转到主页并打开编辑器
      final content = '来自分享的图片:\n\n![图片](file://$imagePath)';
      appRouter.router.go('/', extra: {'sharedContent': content});
    }
    // 🔥 处理分享的多张图片
    else if (call.method == 'onSharedImages') {
      final imagePaths = (call.arguments as List).cast<String>();
      print('🔥 收到分享的图片: ${imagePaths.length}张');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 跳转到主页并打开编辑器
      final buffer = StringBuffer();
      buffer.writeln('来自分享的图片 (${imagePaths.length}张):\n');
      for (final path in imagePaths) {
        buffer.writeln('![图片](file://$path)\n');
      }
      appRouter.router.go('/', extra: {'sharedContent': buffer.toString()});
    }
    // 🔥 处理分享的文件
    else if (call.method == 'onSharedFile') {
      final filePath = call.arguments as String;
      print('🔥 收到分享的文件: $filePath');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 跳转到主页并打开编辑器
      final fileName = filePath.split('/').last;
      final content = '分享的文件:\n\n📎 $fileName\n\n路径: $filePath';
      appRouter.router.go('/', extra: {'sharedContent': content});
    }
  });
  
  // 🔥 关键：检查应用是否从通知点击冷启动（模仿Android的getInitialNoteId）
  try {
    print('🔍 [main.dart] 检查是否从通知点击启动...');
    final initialPayload = await platform.invokeMethod('getInitialPayload');
    if (initialPayload != null && initialPayload is String) {
      print('🔥 [main.dart] 检测到冷启动payload: $initialPayload');
      // 延迟跳转，确保应用完全初始化
      Future.delayed(const Duration(seconds: 1), () {
        print('🚀 [main.dart] 延迟跳转到笔记详情页: $initialPayload');
        appRouter.router.go('/note/$initialPayload');
        appProvider.cancelNoteReminder(initialPayload).catchError((e) {
          print('⚠️ 取消提醒失败: $e');
        });
      });
    } else {
      print('📱 [main.dart] 正常启动（非通知点击）');
    }
  } catch (e) {
    print('⚠️ [main.dart] 检查初始payload失败: $e');
  }
  
  // 运行应用
  runApp(MyApp(appProvider: appProvider, appRouter: appRouter));
}

// 创建自定义页面切换动画
class FadeTransitionPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  FadeTransitionPageRoute({required this.page}) 
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = 0.0;
            const end = 1.0;
            final tween = Tween(begin: begin, end: end);
            final fadeAnimation = animation.drive(tween);
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}

class MyApp extends StatefulWidget {
  final AppProvider appProvider;
  final AppRouter appRouter;
  
  const MyApp({super.key, required this.appProvider, required this.appRouter});
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }
  
  Future<void> _checkForUpdates() async {
    try {
      // 获取当前版本
      final currentVersion = Config.AppConfig.appVersion;
      
      // 获取服务器版本
      final response = await http.get(
        Uri.parse(Config.AppConfig.getCloudNoticeUrl())
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverVersion = data['versionInfo']['versionName'];
        
        // 比较版本号
        if (_shouldUpdate(currentVersion, serverVersion)) {
          if (mounted) {
            _showUpdateDialog(data['versionInfo']);
          }
        }
      }
    } catch (e) {
      // 检查更新失败，静默处理
    }
  }
  
  bool _shouldUpdate(String currentVersion, String serverVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final server = serverVersion.split('.').map(int.parse).toList();
      
      // 确保两个列表长度相同
      while (current.length < server.length) current.add(0);
      while (server.length < current.length) server.add(0);
      
      // 比较每个版本号部分
      for (var i = 0; i < current.length; i++) {
        if (server[i] > current[i]) return true;
        if (server[i] < current[i]) return false;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  void _showUpdateDialog(Map<String, dynamic> versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: !(versionInfo['forceUpdate'] ?? false),
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('墨鸣笔记有新版本可用，建议立即更新以体验新功能！'),
            const SizedBox(height: 16),
            const Text('更新内容：'),
            ...List<Widget>.from(
              (versionInfo['releaseNotes'] as List<dynamic>).map(
                (note) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $note'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!(versionInfo['forceUpdate'] ?? false))
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后再说'),
            ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = versionInfo['downloadUrls']['android'];
              try {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (e) {
                // 启动下载链接失败，静默处理
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 创建路由器
    final appRouter = AppRouter(widget.appProvider);
    
    return ChangeNotifierProvider.value(
      value: widget.appProvider,
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // 获取主题选择和深色模式状态
          final isDarkMode = provider.isDarkMode;
          final themeSelection = provider.themeSelection;
          final themeMode = provider.themeMode;
          
          // 设置状态栏颜色 - 根据当前主题调整
          final statusBarColor = isDarkMode 
              ? AppTheme.darkSurfaceColor
              : Colors.white;
          
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: statusBarColor,
              systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
            ),
          );
          
          // 根据配置选择主题
          final theme = AppTheme.getTheme(themeMode, false); // 亮色主题
          final darkTheme = AppTheme.getTheme(themeMode, true); // 深色主题
          
          // 根据主题选择设置ThemeMode
          ThemeMode appThemeMode;
          if (themeSelection == AppConfig.THEME_SYSTEM) {
            appThemeMode = ThemeMode.system;
          } else if (themeSelection == AppConfig.THEME_LIGHT) {
            appThemeMode = ThemeMode.light;
          } else if (themeSelection == AppConfig.THEME_DARK) {
            appThemeMode = ThemeMode.dark;
          } else {
            appThemeMode = ThemeMode.system;
          }
          
          return MaterialApp.router(
            key: navigatorKey,
            title: 'InkRoot-墨鸣笔记',
            themeMode: appThemeMode,
            theme: theme,
            darkTheme: darkTheme,
            debugShowCheckedModeBanner: false,
            // 配置中文本地化
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('zh', 'CN'),
            routerConfig: widget.appRouter.router,
            // 添加全局页面切换配置
            builder: (context, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}