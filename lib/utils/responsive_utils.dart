import 'package:flutter/material.dart';

class ResponsiveUtils {
  // 屏幕断点定义 (基于Material Design 3规范)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 840;
  static const double desktopBreakpoint = 1200;
  
  // 获取屏幕类型
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }
  
  // 检查是否为小屏设备
  static bool isMobile(BuildContext context) => 
      getScreenType(context) == ScreenType.mobile;
  
  // 检查是否为平板
  static bool isTablet(BuildContext context) => 
      getScreenType(context) == ScreenType.tablet;
  
  // 检查是否为桌面
  static bool isDesktop(BuildContext context) => 
      getScreenType(context) == ScreenType.desktop;
  
  // 响应式值选择器
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
  
  // 响应式字体大小
  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return baseFontSize;
      case ScreenType.tablet:
        return baseFontSize * 1.1;
      case ScreenType.desktop:
        return baseFontSize * 1.2;
    }
  }
  
  // 响应式间距
  static double responsiveSpacing(BuildContext context, double baseSpacing) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return baseSpacing;
      case ScreenType.tablet:
        return baseSpacing * 1.2;
      case ScreenType.desktop:
        return baseSpacing * 1.4;
    }
  }
  
  // 响应式边距
  static EdgeInsets responsivePadding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final multiplier = responsive<double>(
      context,
      mobile: 1.0,
      tablet: 1.2,
      desktop: 1.4,
    );
    
    if (all != null) {
      return EdgeInsets.all(all * multiplier);
    }
    
    return EdgeInsets.only(
      left: (left ?? horizontal ?? 0) * multiplier,
      top: (top ?? vertical ?? 0) * multiplier,
      right: (right ?? horizontal ?? 0) * multiplier,
      bottom: (bottom ?? vertical ?? 0) * multiplier,
    );
  }
  
  // 响应式容器宽度
  static double responsiveContainerWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return responsive<double>(
      context,
      mobile: width * 0.9,
      tablet: width * 0.8,
      desktop: width * 0.6,
    );
  }
  
  // 安全区域感知的高度
  static double safeHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - 
           mediaQuery.padding.top - 
           mediaQuery.padding.bottom;
  }
  
  // 安全区域感知的宽度
  static double safeWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width - 
           mediaQuery.padding.left - 
           mediaQuery.padding.right;
  }
  
  // 响应式按钮尺寸
  static Size responsiveButtonSize(BuildContext context) {
    return responsive<Size>(
      context,
      mobile: const Size(double.infinity, 48),
      tablet: const Size(double.infinity, 52),
      desktop: const Size(double.infinity, 56),
    );
  }
  
  // 响应式图标大小
  static double responsiveIconSize(BuildContext context, double baseSize) {
    return responsive<double>(
      context,
      mobile: baseSize,
      tablet: baseSize * 1.1,
      desktop: baseSize * 1.2,
    );
  }
  
  // 获取最大内容宽度
  static double getMaxContentWidth(BuildContext context) {
    return responsive<double>(
      context,
      mobile: double.infinity,
      tablet: 600,
      desktop: 800,
    );
  }
}

enum ScreenType {
  mobile,
  tablet,
  desktop,
}

// 响应式Widget构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    return builder(context, screenType);
  }
}

// 响应式布局Widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ResponsiveUtils.mobileBreakpoint) {
          return mobile;
        } else if (constraints.maxWidth < ResponsiveUtils.tabletBreakpoint) {
          return tablet ?? mobile;
        } else {
          return desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}

// 响应式容器
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? ResponsiveUtils.getMaxContentWidth(context),
      ),
      padding: padding ?? ResponsiveUtils.responsivePadding(
        context,
        horizontal: 16,
      ),
      margin: margin,
      child: child,
    );
  }
} 