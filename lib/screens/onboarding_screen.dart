import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/app_provider.dart';
import '../services/preferences_service.dart';
import '../themes/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../config/app_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final PreferencesService _preferencesService = PreferencesService();
  int _currentPage = 0;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: '智能笔记管理',
      description: '轻松记录生活中的每一个灵感时刻\n让思考更有条理，让创意永不丢失',
      iconData: Icons.edit_note_rounded,
      gradient: [AppTheme.primaryColor, AppTheme.primaryLightColor],
    ),
    OnboardingPage(
      title: '标签分类系统',
      description: '智能标签让你的笔记井然有序\n快速找到需要的内容，提升工作效率',
      iconData: Icons.tag_rounded,
      gradient: [AppTheme.accentColor, AppTheme.primaryColor],
    ),
    OnboardingPage(
      title: '随时随地同步',
      description: '云端同步确保数据安全\n无论在哪里都能访问你的重要笔记',
      iconData: Icons.sync_rounded,
      gradient: [AppTheme.primaryLightColor, AppTheme.accentColor],
    ),
    OnboardingPage(
      title: '多平台支持',
      description: '支持手机、平板、电脑多端协作\n让你的创作思路在任何设备上延续',
      iconData: Icons.devices_rounded,
      gradient: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    // 重新触发动画
    _slideController.reset();
    _slideController.forward();
  }

  void _markOnboardingComplete() async {
    await _preferencesService.setNotFirstLaunch();
  }

  void _navigateToLogin() {
    _markOnboardingComplete();
    context.go('/login');
  }

  void _continueToLocalMode() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    _markOnboardingComplete();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.setLocalMode(true);

    setState(() {
      _isLoading = false;
    });

    context.go('/');
  }

  void _showRegisterDialog() {
    _markOnboardingComplete();
    context.go('/register');
  }

  void _showResetPasswordDialog() {
    _showDevelopmentDialog('找回密码');
  }

  void _showDevelopmentDialog(String featureName) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: ResponsiveUtils.responsivePadding(context, all: 24),
        title: Row(
          children: [
            Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.construction_rounded,
                color: AppTheme.primaryColor,
                size: ResponsiveUtils.responsiveIconSize(context, 20),
              ),
            ),
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
            Expanded(
              child: Text(
                featureName,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 18),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '该功能正在开发中，敬请期待！\n我们会尽快为您带来更多精彩功能。',
          style: TextStyle(
            color: isDarkMode ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor,
            fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: ResponsiveUtils.responsivePadding(context, horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('好的'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ResponsiveLayout(
            mobile: _buildMobileLayout(isDarkMode),
            tablet: _buildTabletLayout(isDarkMode),
            desktop: _buildDesktopLayout(isDarkMode),
          ),
        ),
      ),
    );
  }

  // 手机布局 - 现代化设计
  Widget _buildMobileLayout(bool isDarkMode) {
    return Container(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          // 顶部区域
          Container(
            height: ResponsiveUtils.responsive<double>(
              context, 
              mobile: 60.0, 
              tablet: 70.0, 
              desktop: 80.0
            ),
            child: _buildTopBar(isDarkMode),
          ),
          
          // 主内容区域 - 固定高度避免溢出
          Expanded(
            child: Container(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildModernPageContent(page, isDarkMode);
                },
              ),
            ),
          ),
          
          // 固定底部区域
          Container(
            padding: ResponsiveUtils.responsivePadding(context, horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 页面指示器
                _buildModernPageIndicator(isDarkMode),
                
                SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                
                // 底部按钮区域
                _buildModernBottomActions(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 现代化顶部栏
  Widget _buildTopBar(bool isDarkMode) {
    return Padding(
      padding: ResponsiveUtils.responsivePadding(context, horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧 Logo 或标题
          Row(
            children: [
              Container(
                width: ResponsiveUtils.responsiveIconSize(context, 32),
                height: ResponsiveUtils.responsiveIconSize(context, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLightColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: ResponsiveUtils.responsiveIconSize(context, 18),
                ),
              ),
              SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
              Text(
                AppConfig.appName,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          
          // 右侧跳过按钮 - 仅在不是最后一页时显示
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: () {
                // 跳到最后一页
                _pageController.animateToPage(
                  _pages.length - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
                padding: ResponsiveUtils.responsivePadding(context, horizontal: 12, vertical: 8),
              ),
              child: Text(
                '跳过',
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 60)),
        ],
      ),
    );
  }

  // 现代化页面内容
  Widget _buildModernPageContent(OnboardingPage page, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: ResponsiveUtils.responsivePadding(context, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标区域 - 使用渐变背景
            Container(
              width: ResponsiveUtils.responsiveIconSize(context, 120),
              height: ResponsiveUtils.responsiveIconSize(context, 120),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: page.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: page.gradient[0].withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                page.iconData,
                size: ResponsiveUtils.responsiveIconSize(context, 60),
                color: Colors.white,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 40)),
            
            // 标题
            Text(
              page.title,
              style: TextStyle(
                fontSize: ResponsiveUtils.responsiveFontSize(context, 28),
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
            
            // 描述
            Text(
              page.description,
              style: TextStyle(
                fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                color: isDarkMode ? Colors.white70 : Colors.black54,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 现代化页面指示器
  Widget _buildModernPageIndicator(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.responsiveSpacing(context, 4),
          ),
          width: index == _currentPage 
              ? ResponsiveUtils.responsiveSpacing(context, 24) 
              : ResponsiveUtils.responsiveSpacing(context, 8),
          height: ResponsiveUtils.responsiveSpacing(context, 8),
          decoration: BoxDecoration(
            color: index == _currentPage
                ? _pages[_currentPage].gradient[0]
                : (isDarkMode ? Colors.white30 : Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // 现代化底部操作区
  Widget _buildModernBottomActions(bool isDarkMode) {
    // 判断是否是最后一页
    final bool isLastPage = _currentPage == _pages.length - 1;
    
    return Column(
      children: [
        // 主要操作按钮
        SizedBox(
          width: double.infinity,
          height: ResponsiveUtils.responsive<double>(
            context,
            mobile: 52.0,
            tablet: 56.0,
            desktop: 60.0,
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (isLastPage) {
                // 最后一页：开始使用
                _navigateToLogin();
              } else {
                // 其他页：下一页
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pages[_currentPage].gradient[0],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: Colors.grey,
            ),
            child: _isLoading
                ? SizedBox(
                    width: ResponsiveUtils.responsiveIconSize(context, 20),
                    height: ResponsiveUtils.responsiveIconSize(context, 20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastPage ? '开始使用' : '下一步',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isLastPage) ...[
                        SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: ResponsiveUtils.responsiveIconSize(context, 20),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        
        // 仅在最后一页显示次要操作按钮
        if (isLastPage) ...[
          SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 12)),
          
          // 次要操作按钮行
          Row(
            children: [
              Expanded(
                child: _buildModernSecondaryButton(
                  icon: Icons.offline_bolt_rounded,
                  label: '本地运行',
                  onPressed: _continueToLocalMode,
                  isDarkMode: isDarkMode,
                ),
              ),
              SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
              Expanded(
                child: _buildModernSecondaryButton(
                  icon: Icons.person_add_rounded,
                  label: '立即注册',
                  onPressed: _showRegisterDialog,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
        
        // 仅在最后一页显示找回密码按钮
        if (isLastPage) ...[
          SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
          
          // 找回密码按钮
          TextButton(
            onPressed: _showResetPasswordDialog,
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.white60 : Colors.black45,
              padding: ResponsiveUtils.responsivePadding(context, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  size: ResponsiveUtils.responsiveIconSize(context, 16),
                ),
                SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 4)),
                Text(
                  '找回密码',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 现代化次要按钮
  Widget _buildModernSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDarkMode,
  }) {
    return Container(
      height: ResponsiveUtils.responsive<double>(
        context,
        mobile: 44.0,
        tablet: 48.0,
        desktop: 52.0,
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          side: BorderSide(
            color: isDarkMode ? Colors.white30 : Colors.black26,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ResponsiveUtils.responsiveIconSize(context, 16),
            ),
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.responsiveFontSize(context, 13),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 平板布局
  Widget _buildTabletLayout(bool isDarkMode) {
    return ResponsiveContainer(
      maxWidth: 600,
      child: _buildMobileLayout(isDarkMode),
    );
  }

  // 桌面布局
  Widget _buildDesktopLayout(bool isDarkMode) {
    return ResponsiveContainer(
      maxWidth: 800,
      child: Row(
        children: [
          // 左侧内容区域
          Expanded(
            flex: 3,
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo 和标题
                  Row(
                    children: [
                      Container(
                        width: ResponsiveUtils.responsiveIconSize(context, 48),
                        height: ResponsiveUtils.responsiveIconSize(context, 48),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryLightColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: ResponsiveUtils.responsiveIconSize(context, 24),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 16)),
                      Text(
                        AppConfig.appName,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.responsiveFontSize(context, 32),
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 40)),
                  
                  // 大标题
                  Text(
                    '静待沉淀',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 48),
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      height: 1.2,
                    ),
                  ),
                  
                  Text(
                    '蓄势鸣响',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 48),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      height: 1.2,
                    ),
                  ),
                  
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                  
                  Text(
                    '专为思考者打造的智能笔记应用\n让每一个灵感都得到妥善保管，让每一次思考都产生价值',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 18),
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      height: 1.6,
                    ),
                  ),
                  
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 48)),
                  
                  // 桌面端按钮
                  _buildDesktopActions(isDarkMode),
                ],
              ),
            ),
          ),
          
          // 右侧图片/动画区域
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _pages[_currentPage].gradient[0].withOpacity(0.1),
                    _pages[_currentPage].gradient[1].withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: _buildModernPageContent(_pages[_currentPage], isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActions(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主按钮
        SizedBox(
          width: 200,
          height: ResponsiveUtils.responsiveSpacing(context, 56),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '开始使用',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
        
        // 次要按钮
        Row(
          children: [
            TextButton.icon(
              onPressed: _continueToLocalMode,
              icon: Icon(Icons.offline_bolt_rounded),
              label: Text('本地运行'),
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 16)),
            TextButton.icon(
              onPressed: _showRegisterDialog,
              icon: Icon(Icons.person_add_rounded),
              label: Text('立即注册'),
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String? image;
  final IconData iconData;
  final List<Color> gradient;

  OnboardingPage({
    required this.title,
    required this.description,
    this.image,
    required this.iconData,
    required this.gradient,
  });
}

// 响应式容器
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveUtils.getMaxContentWidth(context),
        ),
        child: child,
      ),
    );
  }
} 