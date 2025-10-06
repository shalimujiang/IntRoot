import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../themes/app_theme.dart';
import '../utils/responsive_utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          // 拦截系统返回，返回到主页
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: isDarkMode ? Colors.white : null,
            ),
            onPressed: () {
              context.go('/');
            },
          ),
        title: Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: ListView(
            children: [
              // 顶部标语
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
                            color: isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
                    Text(
                      '专注思考，蓄积智慧',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 设置项列表
              _buildSettingsItem(
                context,
                icon: Icons.account_circle,
                title: '账户信息',
                onTap: () => context.push('/account-info'),
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
              // 分隔线
              Container(
                height: 8,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                margin: ResponsiveUtils.responsivePadding(context, vertical: 8),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.feedback_rounded,
                title: '意见反馈',
                onTap: () => context.push('/feedback'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.help,
                title: '帮助',
                onTap: () => context.push('/settings/help'),
              ),
              _buildSettingsItem(
                context,
                icon: Icons.info,
                title: '关于',
                onTap: () => context.push('/settings/about'),
              ),
            ],
          ),
        ),
      ),
      ),
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
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 16)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: arrowColor,
              size: ResponsiveUtils.responsiveIconSize(context, 20),
            ),
          ],
        ),
      ),
    );
  }
} 