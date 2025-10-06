import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class SnackBarUtils {
  static void showSuccess(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      backgroundColor: AppTheme.successColor,
      icon: Icons.check,
    );
  }

  static void showError(BuildContext context, String message, {VoidCallback? onRetry}) {
    if (onRetry != null) {
      _showErrorWithRetry(context, message, onRetry);
    } else {
      _showCustomSnackBar(
        context,
        message,
        backgroundColor: Colors.red.shade600,
        icon: Icons.close,
      );
    }
  }

  static void showInfo(BuildContext context, String message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    _showCustomSnackBar(
      context,
      message,
      backgroundColor: isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor,
      icon: Icons.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      backgroundColor: Colors.orange.shade600,
      icon: Icons.warning,
    );
  }

  /// 显示网络错误提示，会自动根据错误类型提供友好的提示信息
  static void showNetworkError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    String userFriendlyMessage = '网络连接失败，请检查网络设置';
    
    if (error != null) {
      final errorString = error.toString().toLowerCase();
      
      if (errorString.contains('socketexception') || errorString.contains('networkexception')) {
        userFriendlyMessage = '网络连接失败，请检查网络设置';
      } else if (errorString.contains('timeoutexception')) {
        userFriendlyMessage = '连接超时，请检查网络或稍后重试';
      } else if (errorString.contains('formatexception')) {
        userFriendlyMessage = '服务器响应格式错误，请检查服务器地址';
      } else if (errorString.contains('handshakeexception') || errorString.contains('tlsexception')) {
        userFriendlyMessage = 'SSL连接失败，请检查服务器证书';
      } else if (errorString.contains('unauthorized') || errorString.contains('401')) {
        userFriendlyMessage = '登录信息已过期，请重新登录';
      } else if (errorString.contains('forbidden') || errorString.contains('403')) {
        userFriendlyMessage = '没有访问权限，请联系管理员';
      } else if (errorString.contains('notfound') || errorString.contains('404')) {
        userFriendlyMessage = '请求的资源不存在，请检查服务器地址';
      } else if (errorString.contains('server') || errorString.contains('500')) {
        userFriendlyMessage = '服务器内部错误，请稍后重试';
      } else if (errorString.contains('service unavailable') || errorString.contains('503')) {
        userFriendlyMessage = '服务器暂时不可用，请稍后重试';
      }
    }
    
    showError(context, userFriendlyMessage, onRetry: onRetry);
  }

  static void _showErrorWithRetry(BuildContext context, String message, VoidCallback onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '重试',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            onRetry();
          },
        ),
      ),
    );
  }

  static void _showCustomSnackBar(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
