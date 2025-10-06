
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/announcement_model.dart';
import '../themes/app_theme.dart';
import '../themes/app_typography.dart';
import '../utils/snackbar_utils.dart';
import '../utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 页面加载后立即刷新未读通知数量
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).refreshUnreadAnnouncementsCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, isDarkMode),
      tablet: _buildTabletLayout(context, isDarkMode),
      desktop: _buildDesktopLayout(context, isDarkMode),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDarkMode) {
    return Scaffold(
      appBar: _buildResponsiveAppBar(context),
      body: _buildNotificationsList(context, isDarkMode),
    );
  }

  Widget _buildTabletLayout(BuildContext context, bool isDarkMode) {
    return Scaffold(
      appBar: _buildResponsiveAppBar(context),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: _buildNotificationsList(context, isDarkMode),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isDarkMode) {
    return Scaffold(
      appBar: _buildResponsiveAppBar(context),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: _buildNotificationsList(context, isDarkMode),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        '通知中心',
        style: AppTypography.getTitleStyle(context),
      ),
      centerTitle: ResponsiveUtils.isMobile(context) ? false : true,
      actions: [
        // 将刷新按钮改为全部已读按钮
        IconButton(
          icon: Icon(
            Icons.done_all,
            size: ResponsiveUtils.responsiveIconSize(context, 24),
          ),
          onPressed: _isLoading ? null : () => _markAllAsRead(context),
          tooltip: '全部已读',
        ),
        if (!ResponsiveUtils.isMobile(context))
          SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
      ],
    );
  }

  Widget _buildNotificationsList(BuildContext context, bool isDarkMode) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        if (_isLoading) {
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.responsiveIconSize(context, 24),
              height: ResponsiveUtils.responsiveIconSize(context, 24),
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final announcements = appProvider.announcements;
        if (announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: ResponsiveUtils.responsiveIconSize(context, 64),
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
                SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
                Text(
                  '暂无通知',
                  style: AppTypography.getBodyStyle(
                    context,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshAnnouncements(context),
          child: ListView.builder(
            padding: ResponsiveUtils.responsivePadding(
              context,
              vertical: 8,
              horizontal: ResponsiveUtils.isMobile(context) ? 0 : 16,
            ),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return FutureBuilder<bool>(
                future: appProvider.isAnnouncementRead(announcement.id),
                builder: (context, snapshot) {
                  final isRead = snapshot.data ?? false;
                  return _buildAnnouncementCard(
                    context,
                    announcement,
                    isRead,
                    isDarkMode,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementCard(
    BuildContext context,
    Announcement announcement,
    bool isRead,
    bool isDarkMode,
  ) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF1C1C1E)
        : Colors.white;

    final accentColor = Colors.teal;
    final titleColor = isRead
        ? (isDarkMode ? Colors.white : Colors.black87)
        : accentColor;

    final contentColor = isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    final borderRadius = ResponsiveUtils.responsive<double>(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    );

    final iconSize = ResponsiveUtils.responsiveIconSize(context, 44);

    return Container(
      margin: ResponsiveUtils.responsivePadding(
        context,
        horizontal: 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: isRead 
            ? null 
            : Border.all(color: accentColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: ResponsiveUtils.responsiveSpacing(context, 8),
            offset: Offset(0, ResponsiveUtils.responsiveSpacing(context, 2)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: () => _showAnnouncementDetails(context, announcement),
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: ResponsiveUtils.responsivePadding(context, all: 16),
            child: Row(
              children: [
                // 左侧图标
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: isRead 
                        ? Colors.grey.shade200
                        : accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(borderRadius * 0.75),
                  ),
                  child: Icon(
                    _getAnnouncementIcon(announcement.type),
                    color: isRead ? Colors.grey.shade500 : accentColor,
                    size: ResponsiveUtils.responsiveIconSize(context, 22),
                  ),
                ),
                
                SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
                
                // 中间内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: AppTypography.getTitleStyle(
                                context,
                                fontSize: 16,
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
                          Text(
                            _formatDate(announcement.publishDate),
                            style: AppTypography.getCaptionStyle(
                              context,
                              color: contentColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 4)),
                      Text(
                        announcement.content,
                        style: AppTypography.getBodyStyle(
                          context,
                          fontSize: 14,
                          color: contentColor,
                          height: 1.3,
                        ),
                        maxLines: ResponsiveUtils.isMobile(context) ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // 右侧状态指示器
                SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
                Column(
                  children: [
                    if (!isRead)
                      Container(
                        width: ResponsiveUtils.responsiveIconSize(context, 8),
                        height: ResponsiveUtils.responsiveIconSize(context, 8),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      SizedBox(
                        width: ResponsiveUtils.responsiveIconSize(context, 8),
                        height: ResponsiveUtils.responsiveIconSize(context, 8),
                      ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: ResponsiveUtils.responsiveIconSize(context, 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAnnouncementIcon(String type) {
    switch (type) {
      case 'update':
        return Icons.system_update_outlined;
      case 'info':
        return Icons.info_outline;
      case 'event':
        return Icons.event_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshAnnouncements(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.refreshAnnouncements();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '刷新通知失败，请检查网络连接');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.markAllAnnouncementsAsRead();
      
      if (mounted) {
        SnackBarUtils.showSuccess(context, '已将所有通知标记为已读');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '操作失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAnnouncementDetails(BuildContext context, Announcement announcement) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accentColor = Colors.teal;
    
    final dialogWidth = ResponsiveUtils.responsive<double>(
      context,
      mobile: MediaQuery.of(context).size.width * 0.9,
      tablet: 500.0,
      desktop: 600.0,
    );
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.responsiveSpacing(context, 14),
          ),
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Container(
                padding: ResponsiveUtils.responsivePadding(
                  context,
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getAnnouncementIcon(announcement.type),
                      color: accentColor,
                      size: ResponsiveUtils.responsiveIconSize(context, 24),
                    ),
                    SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: AppTypography.getTitleStyle(
                          context,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 分割线
              Container(
                height: 1,
                color: Colors.grey.shade300,
                margin: ResponsiveUtils.responsivePadding(
                  context,
                  horizontal: 24,
                ),
              ),
              
              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: ResponsiveUtils.responsivePadding(
                    context,
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 发布日期
                      Text(
                        _formatDate(announcement.publishDate),
                        style: AppTypography.getCaptionStyle(
                          context,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 12)),
                      
                      // 内容
                      Text(
                        announcement.content,
                        style: AppTypography.getBodyStyle(
                          context,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 按钮区域
              Container(
                padding: ResponsiveUtils.responsivePadding(
                  context,
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    if (announcement.actionUrls != null && announcement.actionUrls!.isNotEmpty)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                            final url = isAndroid
                                ? announcement.actionUrls!['android']
                                : announcement.actionUrls!['ios'];

                            if (url != null) {
                              launchUrl(Uri.parse(url));
                            }
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: ResponsiveUtils.responsivePadding(
                              context,
                              vertical: 12,
                            ),
                            minimumSize: Size(
                              0,
                              ResponsiveUtils.responsiveSpacing(context, 44),
                            ),
                          ),
                          child: Text(
                            announcement.type == 'update' ? '立即更新' : '查看详情',
                            style: AppTypography.getButtonStyle(
                              context,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                    if (announcement.actionUrls != null && announcement.actionUrls!.isNotEmpty)
                      Container(
                        width: 1,
                        height: ResponsiveUtils.responsiveSpacing(context, 20),
                        color: Colors.grey.shade300,
                        margin: ResponsiveUtils.responsivePadding(
                          context,
                          horizontal: 8,
                        ),
                      ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: ResponsiveUtils.responsivePadding(
                            context,
                            vertical: 12,
                          ),
                          minimumSize: Size(
                            0,
                            ResponsiveUtils.responsiveSpacing(context, 44),
                          ),
                        ),
                        child: Text(
                          '确定',
                          style: AppTypography.getButtonStyle(
                            context,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 🔄 标记为已读 - 使用实际的通知内容作为ID
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final actualId = appProvider.cloudNotice?.appGg ?? announcement.id;
    appProvider.markAnnouncementAsRead(actualId);
  }
} 