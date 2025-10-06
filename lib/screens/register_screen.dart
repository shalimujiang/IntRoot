import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../themes/app_theme.dart';
import '../utils/snackbar_utils.dart';
import '../config/app_config.dart';
import '../utils/responsive_utils.dart';
import 'privacy_policy_screen.dart';
import 'user_agreement_screen.dart';
import 'dart:ui';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberLogin = true;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _useCustomServer = false;

  late AnimationController _heroController;
  late AnimationController _formController;
  late AnimationController _floatingController;
  late Animation<double> _heroAnimation;
  late Animation<double> _formAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedServerInfo();
    
    // 精心设计的动画系统
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _formController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutExpo,
    );
    
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    );
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOutSine,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(_formAnimation);
    
    // 启动动画序列
    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _formController.forward();
    });
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _heroController.dispose();
    _formController.dispose();
    _floatingController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedServerInfo() async {
    setState(() {
      _serverController.text = AppConfig.officialMemosServer;
    });
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final savedServer = await appProvider.getSavedServer();
    
    if (savedServer != null && savedServer != AppConfig.officialMemosServer) {
      setState(() {
        _useCustomServer = true;
        _serverController.text = savedServer;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreedToTerms) {
      SnackBarUtils.showWarning(context, '请阅读并同意隐私政策及用户协议');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final serverUrl = _useCustomServer 
        ? _serverController.text.trim() 
        : AppConfig.officialMemosServer;
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      
      final result = await appProvider.registerWithPassword(
        serverUrl, 
        username,
        password,
        remember: _rememberLogin,
      );

      if (result.$1 && mounted) {
        SnackBarUtils.showSuccess(context, '注册成功！正在为您登录...');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.go('/');
        }
      } else if (mounted) {
        SnackBarUtils.showError(
          context, 
          result.$2 ?? '注册失败，请检查信息后重试',
          onRetry: () {
            _register();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showNetworkError(
          context, 
          e,
          onRetry: () {
            _register();
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 🎨 符合现有主题的配色方案
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
        
    final accentGlow = primaryColor.withOpacity(0.1);
    
    return Scaffold(
      backgroundColor: surfaceColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 🌟 背景装饰层 - 现代极简风格
          _buildBackgroundDecoration(isDarkMode, primaryColor),
          
          // 🎭 主要内容层
          SafeArea(
            child: ResponsiveLayout(
              mobile: _buildMobileLayout(isDarkMode, cardColor, textPrimary, textSecondary, primaryColor, accentGlow),
              tablet: _buildTabletLayout(isDarkMode, cardColor, textPrimary, textSecondary, primaryColor, accentGlow),
              desktop: _buildDesktopLayout(isDarkMode, cardColor, textPrimary, textSecondary, primaryColor, accentGlow),
            ),
          ),
        ],
      ),
    );
  }

  // 移动端布局
  Widget _buildMobileLayout(bool isDarkMode, Color cardColor, Color textPrimary, Color textSecondary, Color primaryColor, Color accentGlow) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 🎯 顶部导航栏
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _buildNavButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => context.pop(),
            isDarkMode: isDarkMode,
            cardColor: cardColor,
            textPrimary: textPrimary,
          ),
          actions: [
            _buildNavButton(
              icon: Icons.help_outline,
              onTap: () => _showHelpDialog(),
              isDarkMode: isDarkMode,
              cardColor: cardColor,
              textPrimary: textPrimary,
            ),
          ],
        ),
        
        // 🚀 英雄标题区域
        SliverToBoxAdapter(
          child: _buildHeroSection(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ),
        ),
        
        // 📝 表单区域
        SliverToBoxAdapter(
          child: _buildFormSection(
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
            accentGlow: accentGlow,
            isDarkMode: isDarkMode,
          ),
        ),
        
        // 🔧 设置区域
        SliverToBoxAdapter(
          child: _buildSettingsSection(
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
            isDarkMode: isDarkMode,
          ),
        ),
        
        // 📄 条款区域
        SliverToBoxAdapter(
          child: _buildTermsSection(
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ),
        ),
        
        // 🎯 操作区域
        SliverToBoxAdapter(
          child: _buildActionSection(
            primaryColor: primaryColor,
            textPrimary: textPrimary,
            cardColor: cardColor,
            isDarkMode: isDarkMode,
          ),
        ),
        
        // 📱 底部区域
        SliverToBoxAdapter(
          child: SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 40)),
        ),
      ],
    );
  }

  // 平板布局
  Widget _buildTabletLayout(bool isDarkMode, Color cardColor, Color textPrimary, Color textSecondary, Color primaryColor, Color accentGlow) {
    return ResponsiveContainer(
      maxWidth: 600,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🎯 顶部导航栏
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: _buildNavButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => context.pop(),
              isDarkMode: isDarkMode,
              cardColor: cardColor,
              textPrimary: textPrimary,
            ),
            actions: [
              _buildNavButton(
                icon: Icons.help_outline,
                onTap: () => _showHelpDialog(),
                isDarkMode: isDarkMode,
                cardColor: cardColor,
                textPrimary: textPrimary,
              ),
            ],
          ),
          
          // 🚀 英雄标题区域
          SliverToBoxAdapter(
            child: _buildHeroSection(
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
            ),
          ),
          
          // 📝 表单区域
          SliverToBoxAdapter(
            child: _buildFormSection(
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              accentGlow: accentGlow,
              isDarkMode: isDarkMode,
            ),
          ),
          
          // 🔧 设置区域
          SliverToBoxAdapter(
            child: _buildSettingsSection(
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              isDarkMode: isDarkMode,
            ),
          ),
          
          // 📄 条款区域
          SliverToBoxAdapter(
            child: _buildTermsSection(
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
            ),
          ),
          
          // 🎯 操作区域
          SliverToBoxAdapter(
            child: _buildActionSection(
              primaryColor: primaryColor,
              textPrimary: textPrimary,
              cardColor: cardColor,
              isDarkMode: isDarkMode,
            ),
          ),
          
          // 📱 底部区域
          SliverToBoxAdapter(
            child: SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 60)),
          ),
        ],
      ),
    );
  }

  // 桌面布局
  Widget _buildDesktopLayout(bool isDarkMode, Color cardColor, Color textPrimary, Color textSecondary, Color primaryColor, Color accentGlow) {
    return ResponsiveContainer(
      maxWidth: 800,
      child: Row(
        children: [
          // 左侧信息区域
          Expanded(
            flex: 5,
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加入 InkRoot',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 48),
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                  Text(
                    '开启您的智能笔记之旅',
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
          
          // 右侧注册表单区域
          Expanded(
            flex: 4,
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, all: 48),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFormSection(
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      accentGlow: accentGlow,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                    _buildSettingsSection(
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                    _buildTermsSection(
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                    ),
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 24)),
                    _buildActionSection(
                      primaryColor: primaryColor,
                      textPrimary: textPrimary,
                      cardColor: cardColor,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 背景装饰层
  Widget _buildBackgroundDecoration(bool isDarkMode, Color primaryColor) {
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
              top: 100 + _floatingAnimation.value * 20,
              right: 50,
              child: Container(
                width: 120,
                height: 120,
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
              bottom: 200 - _floatingAnimation.value * 30,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withOpacity(0.08),
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
        color: cardColor.withOpacity(0.8),
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

  // 🚀 英雄标题区域
  Widget _buildHeroSection({
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return FadeTransition(
      opacity: _heroAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_heroAnimation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo区域
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                                      colors: [
                    primaryColor,
                                          AppTheme.primaryLightColor,
                  ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              
              // 主标题
              Text(
                '开启您的\n创作之旅',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 副标题
              Text(
                '加入 InkRoot，记录每一个值得珍藏的时刻',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📝 表单区域
  Widget _buildFormSection({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color accentGlow,
    required bool isDarkMode,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _formAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
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
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                      if (value.length < 3) {
                        return '用户名至少需要3个字符';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(value)) {
                        return '用户名只能包含字母、数字、下划线和中文';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 密码
                  _buildTextField(
                    controller: _passwordController,
                    label: '密码',
                    hint: '至少8位，包含字母或数字',
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
                      if (value.length < 8) {
                        return '密码至少需要8个字符';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 确认密码
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: '确认密码',
                    hint: '请再次输入密码',
                    icon: Icons.lock_outline,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请再次输入密码';
                      }
                      if (value != _passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 设置区域
  Widget _buildSettingsSection({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.03),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.verified_user,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '注册后自动登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '为您提供更便捷的使用体验',
                    style: TextStyle(
                      fontSize: 13,
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
        ),
      ),
    );
  }

  // 📄 条款区域
  Widget _buildTermsSection({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _agreedToTerms = !_agreedToTerms;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _agreedToTerms ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: _agreedToTerms ? primaryColor : textSecondary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _agreedToTerms
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: '我已阅读并同意 '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        '隐私政策',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' 和 '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserAgreementScreen(),
                          ),
                        );
                      },
                      child: Text(
                        '用户协议',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 操作区域
  Widget _buildActionSection({
    required Color primaryColor,
    required Color textPrimary,
    required Color cardColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 注册按钮
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _isLoading || !_agreedToTerms
                  ? null
                  : LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.8),
                      ],
                    ),
              color: _isLoading || !_agreedToTerms
                  ? (isDarkMode ? Colors.grey[700] : Colors.grey[300])
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isLoading || !_agreedToTerms
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
                onTap: _isLoading || !_agreedToTerms ? null : _register,
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
                          '开始创作',
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
          ),
          
          const SizedBox(height: 24),
          
          // 登录链接
          Container(
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login,
                        color: primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已有账号？立即登录',
                        style: TextStyle(
                          fontSize: 15,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

  // 🆘 帮助对话框
  void _showHelpDialog() {
    // 实现帮助对话框
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