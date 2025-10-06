import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../themes/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../routes/app_router.dart'; // 导入自定义路由
import '../screens/home_screen.dart'; // 导入首页
import '../services/announcement_service.dart';
import '../services/cloud_verification_service.dart';
import '../models/cloud_verification_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // 导入公告服务
import '../widgets/update_dialog.dart'; // 导入更新对话框

import 'feedback_screen.dart'; // 导入反馈建议页面
import '../config/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600];
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // 返回首页而不是退出应用
        if (didPop == false) {
          context.go('/');
        }
      },
      child: ResponsiveLayout(
        mobile: _buildMobileLayout(context, backgroundColor, textColor, secondaryTextColor, iconColor, isDarkMode),
        tablet: _buildTabletLayout(context, backgroundColor, textColor, secondaryTextColor, iconColor, isDarkMode),
        desktop: _buildDesktopLayout(context, backgroundColor, textColor, secondaryTextColor, iconColor, isDarkMode),
      ),
    );
  }

  // 移动端布局
  Widget _buildMobileLayout(BuildContext context, Color backgroundColor, Color textColor, Color? secondaryTextColor, Color iconColor, bool isDarkMode) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, isDarkMode),
        body: Column(
          children: [
            // 顶部标语
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
              children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Text(
                        '静待沉淀',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '蓄势鸣响',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你的每一次落笔，都是未来生长的根源。',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                            ),
                    ),
                  ],
                ),
            ),
                
            // 设置列表
            Expanded(
              child: ListView(
                  children: [
                    _buildSettingsItem(
                      context,
                      icon: Icons.account_circle,
                      title: '账户信息',
                      onTap: () {
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        if (appProvider.isLoggedIn) {
                          // 已登录，直接前往账户信息页面
                          context.push('/account-info');
                        } else {
                          // 未登录，显示提示对话框
                          _showLoginPromptDialog(context);
                        }
                      },
                    ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.cloud,
                    title: '服务器连接',
                    onTap: () => context.push('/server-info'),
                    ),
                    _buildSettingsItem(
                      context,
                    icon: Icons.settings,
                    title: '偏好设置',
                    onTap: () => context.push('/preferences'),
                    ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.import_export,
                    title: '导入导出',
                    onTap: () => context.push('/import-export'),
                      ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.cleaning_services,
                    title: '数据清理',
                    onTap: () => context.push('/data-cleanup'),
                    ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.science,
                    title: '实验室',
                    onTap: () => context.push('/laboratory'),
                  ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.system_update_outlined,
                    title: '检查更新',
                    onTap: () => _checkForUpdates(context),
                  ),
                    _buildSettingsItem(
                      context,
                    icon: Icons.feedback_outlined,
                    title: '反馈建议',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackScreen(),
                      ),
                    ),
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.help_outline,
                      title: '帮助中心',
                      onTap: () => context.push('/settings/help'),
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.info_outline,
                      title: '关于我们',
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
            ),
                
            // 底部区域
            Consumer<AppProvider>(
              builder: (context, appProvider, child) {
                return Column(
                  children: [
                    // 只在非本地模式下显示退出登录按钮
                    if (!appProvider.isLocalMode)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton(
                          onPressed: () => _confirmLogout(context),
                          child: const Text(
                            '退出登录',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${AppConfig.appName}-${AppConfig.appVersion}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 平板布局
  Widget _buildTabletLayout(BuildContext context, Color backgroundColor, Color textColor, Color? secondaryTextColor, Color iconColor, bool isDarkMode) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, isDarkMode),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: _buildSettingsContent(context, textColor, secondaryTextColor, iconColor, isDarkMode),
      ),
    );
  }

  // 桌面布局
  Widget _buildDesktopLayout(BuildContext context, Color backgroundColor, Color textColor, Color? secondaryTextColor, Color iconColor, bool isDarkMode) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, isDarkMode),
      body: ResponsiveContainer(
        maxWidth: 800,
        child: Row(
          children: [
            // 左侧信息区域
            Expanded(
              flex: 2,
              child: Container(
                padding: ResponsiveUtils.responsivePadding(context, all: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '静待沉淀',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 32),
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
                    Text(
                      '蓄势鸣响',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 32),
                        fontWeight: FontWeight.w500,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
                    Text(
                      '你的每一次落笔，都是未来生长的根源。',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                        color: secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右侧设置区域
            Expanded(
              flex: 3,
              child: Container(
                padding: ResponsiveUtils.responsivePadding(context, all: 32),
                child: _buildSettingsContent(context, textColor, secondaryTextColor, iconColor, isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 响应式AppBar
  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context, Color backgroundColor, Color textColor, bool isDarkMode) {
    return AppBar(
      leading: IconButton(
        icon: Icon(
          Icons.close, 
          color: isDarkMode ? Colors.white : null,
          size: ResponsiveUtils.responsiveIconSize(context, 24),
        ),
        onPressed: () {
          context.go('/');
        },
      ),
      title: Text(
        '设置', 
        style: TextStyle(
          fontSize: ResponsiveUtils.responsiveFontSize(context, 17), 
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: backgroundColor,
    );
  }

  // 设置内容区域
  Widget _buildSettingsContent(BuildContext context, Color textColor, Color? secondaryTextColor, Color iconColor, bool isDarkMode) {
    return Column(
      children: [
        // 顶部标语 (只在移动端显示)
        if (ResponsiveUtils.isMobile(context))
          Container(
            padding: ResponsiveUtils.responsivePadding(context, vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '静待沉淀',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 24),
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 16)),
                    Text(
                      '蓄势鸣响',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 24),
                        fontWeight: FontWeight.w500,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
                Text(
                  '你的每一次落笔，都是未来生长的根源。',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        
        // 设置列表
        Expanded(
          child: ListView(
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.account_circle,
                title: '账户信息',
                onTap: () {
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  if (appProvider.isLoggedIn) {
                    context.push('/account-info');
                  } else {
                    _showLoginPromptDialog(context);
                  }
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.data_usage,
                title: '数据清理',
                onTap: () => context.push('/data-cleanup'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.file_download,
                title: '导入导出',
                onTap: () => context.push('/import-export'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.settings,
                title: '偏好设置',
                onTap: () => context.push('/preferences'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.science,
                title: '实验室',
                onTap: () => context.push('/laboratory'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.info,
                title: '关于',
                onTap: () => context.push('/about'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.help,
                title: '帮助',
                onTap: () => context.push('/help'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.feedback,
                title: '反馈建议',
                onTap: () => context.push('/feedback'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.privacy_tip,
                title: '隐私政策',
                onTap: () => context.push('/privacy-policy'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.description,
                title: '用户协议',
                onTap: () => context.push('/user-agreement'),
              ),
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 32)),
              // 版本信息
              Container(
                alignment: Alignment.center,
                padding: ResponsiveUtils.responsivePadding(context, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      '${AppConfig.appName} ${AppConfig.appVersion}',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 4)),
                        Text(
                          '构建版本：${snapshot.data?.buildNumber ?? ''}',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : null;
    final arrowColor = isDarkMode ? Colors.grey[400] : Colors.grey;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: ResponsiveUtils.responsivePadding(context, horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: ResponsiveUtils.responsiveIconSize(context, 24),
              color: iconColor,
            ),
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: ResponsiveUtils.responsiveIconSize(context, 20),
              color: arrowColor,
            ),
          ],
        ),
      ),
    );
  }
  
  // 显示未登录提示对话框
  void _showLoginPromptDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : AppTheme.textSecondaryColor;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_circle,
                  color: AppTheme.primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Text(
                '未登录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              // 内容
              Text(
                '您当前未登录，无法查看账户信息。是否前往登录页面？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // 按钮
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 登录按钮
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/login');
                      },
                      child: const Text(
                        '去登录',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 已移除 _showLabDialog 方法，现在直接跳转到实验室页面
  
  
  // 检查更新 - 使用云验证服务
  Future<void> _checkForUpdates(BuildContext context) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // 获取当前版本信息
    final currentVersion = AppConfig.appVersion;
    
    // 使用云验证服务检查更新
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.refreshCloudData();
    final hasUpdate = await appProvider.hasCloudUpdate();
    final cloudConfig = appProvider.cloudAppConfig;
    
    // 关闭加载对话框
    if (context.mounted) {
      Navigator.pop(context);
      
      if (cloudConfig == null) {
        // 检查更新失败
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('检查更新失败，请检查网络连接'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (!hasUpdate) {
        // 已是最新版本
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('您当前已是最新版本'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // 显示云验证更新对话框
        _showCloudUpdateDialog(context, cloudConfig, currentVersion);
      }
    }
  }

  // 显示云验证更新对话框
  void _showCloudUpdateDialog(BuildContext context, CloudAppConfigData cloudConfig, String currentVersion) {
    showDialog(
      context: context,
      barrierDismissible: !cloudConfig.isForceUpdate,
      builder: (context) => AlertDialog(
        title: Text(
          '发现新版本',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: $currentVersion'),
            Text('最新版本: ${cloudConfig.version}'),
            if (cloudConfig.versionInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...cloudConfig.formattedVersionInfo.map((info) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $info'),
                )
              ),
            ],
            if (cloudConfig.isForceUpdate) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '这是强制更新版本，必须更新后才能继续使用',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!cloudConfig.isForceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后更新'),
            ),
          ElevatedButton(
            onPressed: () => _launchUpdateUrl(context, cloudConfig.appUpdateUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: cloudConfig.isForceUpdate ? Colors.red : AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(cloudConfig.isForceUpdate ? '立即更新' : '更新'),
          ),
        ],
      ),
    );
  }

  // 启动更新链接
  void _launchUpdateUrl(BuildContext context, String updateUrl) async {
    print('Settings: 准备打开更新链接 - $updateUrl');
    
    if (updateUrl.isEmpty || updateUrl == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新链接无效')),
      );
      return;
    }

    try {
      final Uri url = Uri.parse(updateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        Navigator.pop(context); // 关闭对话框
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $updateUrl')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开链接失败: $e')),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
                    applicationName: AppConfig.appName,
                  applicationVersion: AppConfig.appVersion,
        applicationIcon: const FlutterLogo(size: 32),
        children: const [
                      Text('${AppConfig.appName} 是一个简洁高效的笔记应用。'),
            SizedBox(height: 8),
            Text(AppConfig.copyrightText),
        ],
      ),
    );
  }
  
  void _confirmLogout(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 显示选项对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出登录时如何处理云端数据？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 清空本地数据
              _processLogout(context, appProvider, keepLocalData: false);
            },
            child: const Text('清空云端数据'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 保留本地数据
              _processLogout(context, appProvider, keepLocalData: true);
            },
            child: Text(
              '保留云端数据',
              style: TextStyle(
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _processLogout(BuildContext context, AppProvider appProvider, {required bool keepLocalData}) {
    // 先检查是否有未同步的笔记
    appProvider.logout(keepLocalData: keepLocalData).then((result) {
      final (success, message) = result;
      
      if (!success && message != null) {
        // 有未同步的笔记，显示确认对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  // 用户确认退出，强制退出
                  Navigator.pop(context);
                  // 强制退出登录
                  appProvider.logout(force: true, keepLocalData: keepLocalData).then((_) {
                    context.go('/login');
                  });
                },
                child: Text(
                  '确定退出',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (success) {
        // 没有未同步的笔记，直接退出
        context.go('/login');
      } else {
        // 退出失败，显示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? '退出登录失败')),
        );
      }
    });
  }
} 