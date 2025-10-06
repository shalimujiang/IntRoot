import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';
import '../screens/random_review_screen.dart';
import '../screens/tags_screen.dart';
import '../screens/help_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/account_info_screen.dart';
import '../screens/server_info_screen.dart';
import '../screens/import_export_screen.dart';
import '../screens/about_screen.dart';
import '../screens/preferences_screen.dart';
import '../screens/data_cleanup_screen.dart';
import '../screens/splash_screen.dart';
import '../models/note_model.dart';
import '../services/preferences_service.dart';
import '../screens/notifications_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/laboratory_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/note_detail_screen.dart';


// 自定义路由，用于实现从上往下的返回动画


// 定义统一的侧滑动画 - 优化版
CustomTransitionPage<void> buildSlideTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  Offset? begin,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 使用更平滑的曲线
      final primaryAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic, // 更加平滑的曲线
        reverseCurve: Curves.easeInCubic, // 更加平滑的返回曲线
      );
      
      // 简化动画堆叠，直接使用Transform进行硬件加速
      return AnimatedBuilder(
        animation: primaryAnimation,
        builder: (context, child) {
          return Transform.translate(
            // 使用Transform.translate替代SlideTransition获得更好的硬件加速
            offset: Offset(
              (begin?.dx ?? 0.6) * (1 - primaryAnimation.value) * MediaQuery.of(context).size.width, // 减小偏移量
              0,
            ),
            child: Opacity(
              opacity: primaryAnimation.value,
              child: child,
            ),
          );
        },
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 220), // 减少动画时间提高流畅度
    reverseTransitionDuration: const Duration(milliseconds: 200), // 返回动画更快
  );
}



class AppRouter {
  final AppProvider appProvider;
  final PreferencesService _preferencesService = PreferencesService();
  
  AppRouter(this.appProvider);
  
  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // 启动页路由
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) {
          // 🔥 接收分享的内容
          final extra = state.extra as Map<String, dynamic>?;
          final sharedContent = extra?['sharedContent'] as String?;
          
          return buildSlideTransition(
            context: context,
            state: state,
            begin: const Offset(0.8, 0.0),
            child: HomeScreen(sharedContent: sharedContent),
          );
        },
        routes: [
          GoRoute(
            path: 'account-info',
            name: 'accountInfo',
            builder: (context, state) => const AccountInfoScreen(),
          ),
          
          GoRoute(
            path: 'server-info',
            name: 'serverInfo',
            builder: (context, state) => const ServerInfoScreen(),
          ),
          
          GoRoute(
            path: 'import-export',
            name: 'importExport',
            builder: (context, state) => const ImportExportScreen(),
          ),
          
          GoRoute(
            path: 'data-cleanup',
            name: 'dataCleanup',
            builder: (context, state) => const DataCleanupScreen(),
          ),
          
          GoRoute(
            path: 'preferences',
            name: 'preferences',
            builder: (context, state) => const PreferencesScreen(),
          ),
          
          GoRoute(
            path: 'login',
            name: 'login',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              child: const LoginScreen(showBackButton: true),
            ),
          ),
          
          GoRoute(
            path: 'register',
            name: 'register',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              child: const RegisterScreen(),
            ),
          ),
          
          GoRoute(
            path: 'forgot-password',
            name: 'forgotPassword',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              child: const ForgotPasswordScreen(),
            ),
          ),
          
          GoRoute(
            path: 'random-review',
            name: 'randomReview',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              child: const RandomReviewScreen(),
            ),
          ),
          
          GoRoute(
            path: 'tags',
            name: 'tags',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              child: const TagsScreen(),
            ),
          ),
          
          GoRoute(
            path: 'notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          
          // 笔记详情页
          GoRoute(
            path: 'note/:id',
            name: 'noteDetail',
            pageBuilder: (context, state) {
              final noteId = state.pathParameters['id']!;
              return buildSlideTransition(
                context: context,
                state: state,
                child: NoteDetailScreen(noteId: noteId),
              );
            },
          ),

        ],
      ),
      
      // 顶级帮助中心路由
      GoRoute(
        path: '/help',
        name: 'help',
        pageBuilder: (context, state) => buildSlideTransition(
          context: context,
          state: state,
          begin: const Offset(0.8, 0.0),
          child: const HelpScreen(),
        ),
      ),
      
      // 添加设置路由
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => buildSlideTransition(
          context: context,
          state: state,
          begin: const Offset(1.0, 0.0),
          child: const SettingsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'help',
            name: 'settingsHelp',
            pageBuilder: (context, state) => buildSlideTransition(
              context: context,
              state: state,
              begin: const Offset(0.8, 0.0),
              child: const HelpScreen(),
            ),
          ),
          
          GoRoute(
            path: 'about',
            name: 'settingsAbout',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AboutScreen(),
            ),
          ),
        ],
      ),
      
      // 添加反馈路由
      GoRoute(
        path: '/feedback',
        name: 'feedback',
        pageBuilder: (context, state) => buildSlideTransition(
          context: context,
          state: state,
          begin: const Offset(1.0, 0.0),
          child: const FeedbackScreen(),
        ),
      ),
      
      // 添加实验室路由
      GoRoute(
        path: '/laboratory',
        name: 'laboratory',
        pageBuilder: (context, state) => buildSlideTransition(
          context: context,
          state: state,
          begin: const Offset(1.0, 0.0),
          child: const LaboratoryScreen(),
        ),
      ),
      
      // 添加通知路由为顶级路由
      GoRoute(
        path: '/notifications',
        name: 'notificationsPage',
        builder: (context, state) => const NotificationsScreen(),
      ),
      
    ],
    
    redirect: (context, state) async {
        final isFirstLaunch = await _preferencesService.isFirstLaunch();
        
        if (isFirstLaunch && state.matchedLocation != '/onboarding' && state.matchedLocation != '/welcome') {
          return '/onboarding';
        }
        
        if (state.matchedLocation == '/daily-review') {
          return '/random-review';
      }
      
      return null;
    },
    
    errorBuilder: (context, state) => MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('页面未找到'),
        ),
        body: const Center(
          child: Text('哎呀，页面走丢了!'),
        ),
      ),
    ),
  );
} 