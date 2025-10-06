import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../themes/app_theme.dart';
import '../utils/snackbar_utils.dart';
import '../config/app_config.dart';
import '../utils/responsive_utils.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  final bool showBackButton;
  
  const LoginScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberLogin = true;
  bool _obscurePassword = true;
  bool _useCustomServer = false;

  // 🎬 动画控制器
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _floatingController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    print('LoginScreen: initState');
    _loadSavedLoginInfo();
    _rememberLogin = true;
    
    // 🎨 初始化动画系统
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOutSine,
    ));
    
    // 🎬 启动动画序列
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _floatingController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginInfo() async {
    print('LoginScreen: 加载保存的登录信息');
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final savedServer = await appProvider.getSavedServer();
    final savedUsername = await appProvider.getSavedUsername();
    final savedPassword = await appProvider.getSavedPassword();
    final savedToken = await appProvider.getSavedToken(); // 获取保存的token
    
    setState(() {
      _serverController.text = AppConfig.officialMemosServer;
    });
    
    if (savedServer != null && savedServer != AppConfig.officialMemosServer) {
      print('LoginScreen: 发现保存的自定义服务器信息');
      setState(() {
        _useCustomServer = true;
        _serverController.text = savedServer;
      });
    }
    
    if (savedUsername != null) {
      print('LoginScreen: 发现保存的用户名');
      setState(() {
        _usernameController.text = savedUsername;
      });
    }
    
    if (savedPassword != null) {
      print('LoginScreen: 发现保存的密码');
      setState(() {
        _passwordController.text = savedPassword;
      });
    }

    // 🔑 检查是否有有效的token可以快速登录
    if (savedToken != null && savedServer != null && savedUsername != null) {
      print('LoginScreen: 发现保存的Token，尝试快速登录验证');
      _attemptQuickLogin(savedServer, savedToken);
    }
  }

  // 🚀 尝试使用保存的token快速登录
  Future<void> _attemptQuickLogin(String serverUrl, String token) async {
    try {
      print('LoginScreen: 开始Token验证登录');
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      
      // 尝试使用token登录
      final result = await appProvider.loginWithToken(serverUrl, token, remember: true);
      
      if (result.$1 && mounted) {
        print('LoginScreen: Token验证成功，直接登录');
        
        // 成功则直接跳转到主页
        context.go('/');
        
        // 后台同步数据
        Future.delayed(const Duration(milliseconds: 500), () async {
          try {
            print('LoginScreen: 开始后台数据同步');
            await appProvider.fetchNotesFromServer();
            print('LoginScreen: 后台同步完成');
          } catch (e) {
            print('LoginScreen: 后台同步失败: $e');
          }
        });
      } else {
        print('LoginScreen: Token验证失败: ${result.$2}，需要重新登录');
        // Token失效，清除保存的登录信息，让用户手动登录
        await appProvider.clearLoginInfo();
      }
    } catch (e) {
      print('LoginScreen: Token验证异常: $e');
      // 异常情况下清除保存的登录信息
      if (mounted) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        await appProvider.clearLoginInfo();
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final serverUrl = _useCustomServer 
        ? _serverController.text.trim() 
        : AppConfig.officialMemosServer;
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      
      print('LoginScreen: 尝试登录，记住密码: $_rememberLogin');
      
      final result = await appProvider.loginWithPassword(
        serverUrl, 
        username,
        password,
        remember: _rememberLogin,
      );

      if (result.$1 && mounted) {
        print('LoginScreen: 登录成功，立即进入主界面');
        
        // 🎉 显示成功提示
        await _showSuccessLoginDialog();
        
        // 🎉 成功动画
        await _scaleController.reverse();
        
        context.go('/');
        
        // 后台执行数据同步
        Future.microtask(() async {
          try {
            print('LoginScreen: 开始后台数据同步');
            await appProvider.fetchNotesFromServer();
        final hasLocalData = await appProvider.hasLocalData();
        if (hasLocalData) {
              await appProvider.syncLocalDataToServer();
            }
            print('LoginScreen: 后台同步完成');
          } catch (e) {
            print('LoginScreen: 后台同步失败: $e');
        }
        });
      } else if (mounted) {
        print('LoginScreen: 登录失败: ${result.$2}');
        SnackBarUtils.showError(
          context, 
          result.$2 ?? '登录失败，请检查账号密码和服务器地址',
          onRetry: () => _login(),
        );
      }
    } catch (e) {
      print('LoginScreen: 登录异常: $e');
      if (mounted) {
        SnackBarUtils.showNetworkError(
          context, 
          e,
          onRetry: () => _login(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🎉 显示登录成功对话框
  Future<void> _showSuccessLoginDialog() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: ResponsiveUtils.responsivePadding(context, all: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 成功动画图标
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: ResponsiveUtils.responsiveIconSize(context, 80),
                      height: ResponsiveUtils.responsiveIconSize(context, 80),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.1),
                            Colors.green.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: ResponsiveUtils.responsiveIconSize(context, 50),
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 20)),
              
              Text(
                '登录成功！',
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 12)),
              
              Text(
                '欢迎回来！正在为您准备个人笔记空间...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 20)),
              
              // 加载进度指示器
              SizedBox(
                width: ResponsiveUtils.responsive<double>(
                  context,
                  mobile: 200.0,
                  tablet: 220.0,
                  desktop: 250.0,
                ),
                child: LinearProgressIndicator(
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
    
    // 1.5秒后自动关闭对话框
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 🎨 现代化配色方案 - 绿色主题
    final primaryColor = AppTheme.primaryColor;
    final primaryLight = AppTheme.primaryLightColor;
    final primaryDark = AppTheme.primaryDarkColor;
    
    final surfaceColor = isDarkMode 
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
        
    final cardColor = isDarkMode 
        ? AppTheme.darkCardColor
        : AppTheme.surfaceColor;
        
    final textPrimary = isDarkMode 
        ? AppTheme.darkTextPrimaryColor
        : AppTheme.textPrimaryColor;
        
    final textSecondary = isDarkMode 
        ? AppTheme.darkTextSecondaryColor
        : AppTheme.textSecondaryColor;

    return Scaffold(
      backgroundColor: surfaceColor,
      extendBodyBehindAppBar: true,
      appBar: widget.showBackButton 
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: _buildNavButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => context.go('/'),
                isDarkMode: isDarkMode,
                cardColor: cardColor,
                textPrimary: textPrimary,
              ),
            )
          : null,
      body: Stack(
        children: [
          // 🌟 背景装饰层
          _buildBackgroundDecoration(isDarkMode, primaryColor, screenHeight),
          
          // 🎭 主要内容层
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: ResponsiveLayout(
                mobile: _buildMobileLayout(textPrimary, textSecondary, primaryColor, primaryLight, cardColor, isDarkMode),
                tablet: _buildTabletLayout(textPrimary, textSecondary, primaryColor, primaryLight, cardColor, isDarkMode),
                desktop: _buildDesktopLayout(textPrimary, textSecondary, primaryColor, primaryLight, cardColor, isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 移动端布局
  Widget _buildMobileLayout(Color textPrimary, Color textSecondary, Color primaryColor, Color primaryLight, Color cardColor, bool isDarkMode) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 🚀 英雄区域
        SliverToBoxAdapter(
          child: _buildHeroSection(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ),
        ),
        
        // 📝 登录表单
        SliverToBoxAdapter(
          child: _buildLoginForm(
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
            primaryLight: primaryLight,
            isDarkMode: isDarkMode,
          ),
        ),
        
        // 🔗 快速操作
        SliverToBoxAdapter(
          child: _buildQuickActions(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ),
        ),
        
        // 📱 底部空间
        SliverToBoxAdapter(
          child: SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 40)),
        ),
      ],
    );
  }

  // 平板布局
  Widget _buildTabletLayout(Color textPrimary, Color textSecondary, Color primaryColor, Color primaryLight, Color cardColor, bool isDarkMode) {
    return ResponsiveContainer(
      maxWidth: 600,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🚀 英雄区域
          SliverToBoxAdapter(
            child: _buildHeroSection(
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
            ),
          ),
          
          // 📝 登录表单
          SliverToBoxAdapter(
            child: _buildLoginForm(
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              primaryLight: primaryLight,
              isDarkMode: isDarkMode,
            ),
          ),
          
          // 🔗 快速操作
          SliverToBoxAdapter(
            child: _buildQuickActions(
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
            ),
          ),
          
          // 📱 底部空间
          SliverToBoxAdapter(
            child: SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 60)),
          ),
        ],
      ),
    );
  }

  // 桌面布局
  Widget _buildDesktopLayout(Color textPrimary, Color textSecondary, Color primaryColor, Color primaryLight, Color cardColor, bool isDarkMode) {
    return ResponsiveContainer(
      maxWidth: 800,
      child: Row(
        children: [
          // 左侧装饰区域
          Expanded(
            flex: 5,
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 48),
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                  Text(
                    '智能笔记管理，\n让思考更有条理',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 24),
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 右侧登录区域
          Expanded(
            flex: 4,
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLoginForm(
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryColor: primaryColor,
                    primaryLight: primaryLight,
                    isDarkMode: isDarkMode,
                  ),
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 32)),
                  _buildQuickActions(
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 背景装饰层
  Widget _buildBackgroundDecoration(bool isDarkMode, Color primaryColor, double screenHeight) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // 渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [
                          AppTheme.darkBackgroundColor,
                          AppTheme.darkSurfaceColor,
                          AppTheme.darkCardColor,
                        ]
                      : [
                          AppTheme.backgroundColor,
                          AppTheme.surfaceColor,
                          Colors.white,
          ],
        ),
              ),
            ),
            
            // 浮动装饰圆圈
            Positioned(
              top: screenHeight * 0.15 + _floatingAnimation.value * 30,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                      Colors.transparent,
                    ],
          ),
                ),
      ),
            ),
            
            // 左侧装饰
            Positioned(
              bottom: screenHeight * 0.3 - _floatingAnimation.value * 20,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🎯 导航按钮
  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDarkMode,
    required Color cardColor,
    required Color textPrimary,
  }) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Material(
        color: cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
      ),
            ),
            child: Icon(
              icon,
              color: textPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 英雄区域
  Widget _buildHeroSection({
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    // 根据屏幕类型判断是否显示英雄区域
    if (ResponsiveUtils.isDesktop(context)) {
      return const SizedBox.shrink(); // 桌面版本不显示英雄区域
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_fadeAnimation),
        child: Container(
          padding: ResponsiveUtils.responsivePadding(
            context, 
            horizontal: 32, 
            vertical: 60
          ),
          child: Column(
            children: [
              // Logo区域
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: ResponsiveUtils.responsive<double>(
                    context,
                    mobile: 80.0,
                    tablet: 100.0,
                  ),
                  height: ResponsiveUtils.responsive<double>(
                    context,
                    mobile: 80.0,
                    tablet: 100.0,
                  ),
                  margin: ResponsiveUtils.responsivePadding(
                    context,
                    bottom: 32,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        AppTheme.primaryLightColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: ResponsiveUtils.responsiveIconSize(context, 40),
                  ),
                ),
              ),
              
              // 主标题
              Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 36),
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 12)),
              
              // 副标题
              Text(
                '继续您的创作之旅',
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                  color: textSecondary,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
              
              // 版本兼容性提示
              Container(
                padding: ResponsiveUtils.responsivePadding(
                  context,
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.08),
                      AppTheme.primaryLightColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: ResponsiveUtils.responsiveIconSize(context, 16),
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 12)),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '仅支持 Memos 0.21.0',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.responsiveFontSize(context, 13),
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 2)),
                          Text(
                            'API版本差异较大，0.21.0更稳定',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.responsiveFontSize(context, 11),
                              color: textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
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
  }

  // 📝 登录表单
  Widget _buildLoginForm({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color primaryLight,
    required bool isDarkMode,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: ResponsiveUtils.responsivePadding(context, horizontal: 24),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(ResponsiveUtils.responsive<double>(
              context,
              mobile: 24.0,
              tablet: 28.0,
              desktop: 32.0,
            )),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDarkMode 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                            ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 服务器选择
                      _buildServerSection(textPrimary, textSecondary, primaryColor, isDarkMode),
                      
                      const SizedBox(height: 24),
                      
                      // 用户名
                      _buildTextField(
                        controller: _usernameController,
                        label: '用户名',
                        hint: '请输入您的用户名',
                        icon: Icons.person_outline,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primaryColor: primaryColor,
                        isDarkMode: isDarkMode,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入用户名';
                          }
                          if (value.length < 2) {
                            return '用户名至少需要2个字符';
                          }
                          if (value.contains(' ')) {
                            return '用户名不能包含空格';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 密码
                      _buildTextField(
                        controller: _passwordController,
                        label: '密码',
                        hint: '请输入您的密码',
                        icon: Icons.lock_outline,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primaryColor: primaryColor,
                        isDarkMode: isDarkMode,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入密码';
                          }
                          if (value.length < 6) {
                            return '密码至少需要6个字符';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 记住密码开关
                      _buildRememberSwitch(textPrimary, textSecondary, primaryColor),
                      
                      const SizedBox(height: 32),
                      
                      // 登录按钮
                      _buildLoginButton(primaryColor, primaryLight, isDarkMode),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 服务器选择区域
  Widget _buildServerSection(Color textPrimary, Color textSecondary, Color primaryColor, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.dns_outlined,
            color: primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          _useCustomServer ? '自定义服务器' : '官方服务器',
          style: TextStyle(
            fontSize: 15,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _useCustomServer ? _serverController.text : '推荐使用',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        trailing: TextButton(
          onPressed: _showCustomServerDialog,
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            _useCustomServer ? '更改' : '自定义',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // 📝 输入框组件
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDarkMode,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 16,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 16,
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDarkMode 
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ],
    );
  }

  // 💡 记住密码开关
  Widget _buildRememberSwitch(Color textPrimary, Color textSecondary, Color primaryColor) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
                                ),
          child: Icon(
            Icons.save_alt,
            color: primaryColor,
            size: 12,
                              ),
                            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                            Text(
                '记住密码',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                            ),
              const SizedBox(height: 2),
                            Text(
                '保存账号和密码到本地',
                              style: TextStyle(
                                fontSize: 12,
                  color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
        Switch.adaptive(
          value: _rememberLogin,
          activeColor: primaryColor,
          onChanged: (value) {
            setState(() {
              _rememberLogin = value;
            });
          },
        ),
      ],
    );
  }

  // 🎯 登录按钮
  Widget _buildLoginButton(Color primaryColor, Color primaryLight, bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : LinearGradient(
                colors: [
                  primaryColor,
                  primaryLight,
                ],
              ),
        color: _isLoading
            ? (isDarkMode ? Colors.grey[700] : Colors.grey[300])
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _login,
          child: Container(
            alignment: Alignment.center,
                          child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                : Text(
                    '登录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // 🔗 快速操作
  Widget _buildQuickActions({
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
                          children: [
          Text(
            '还没有账号？',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor,
                width: 1.5,
                              ),
                            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/register'),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    '立即注册',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
            
          const SizedBox(height: 32),
            
            // 版本兼容性详细说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support,
                        size: 18,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '版本兼容性说明',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 本应用专为 Memos 0.21.0 版本优化\n• 不同版本的 API 接口存在较大差异\n• 0.21.0 版本经过充分测试，功能稳定\n• 建议使用指定版本以获得最佳体验',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '如有疑问，请查看官方文档或联系技术支持',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
                          ],
                        ),
    );
  }

  // 🔧 自定义服务器对话框
  void _showCustomServerDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.surfaceColor;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final primaryColor = AppTheme.primaryColor;
    
    final customServerController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: dialogColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Row(
                        children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                                  ),
                      child: Icon(
                        Icons.dns_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                                ),
                    const SizedBox(width: 16),
                    Text(
                      '自定义服务器',
                                  style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                                  ),
                                ),
                  ],
                            ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                                ),
                      const SizedBox(width: 12),
                      Expanded(
                                child: Text(
                          '使用自定义服务器可能会影响使用体验',
                                  style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                    ],
                          ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: customServerController,
                  decoration: InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://your-server.com',
                    prefixIcon: Icon(Icons.language, color: primaryColor),
                    filled: true,
                    fillColor: isDarkMode 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  style: TextStyle(fontSize: 16, color: textColor),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '取消',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        final customServer = customServerController.text.trim();
                        if (customServer.isNotEmpty) {
                          setState(() {
                            _useCustomServer = true;
                            _serverController.text = customServer.startsWith('http') 
                              ? customServer 
                              : 'https://$customServer';
                          });
                        }
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
} 