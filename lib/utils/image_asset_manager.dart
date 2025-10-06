import 'package:flutter/material.dart';
import 'responsive_utils.dart';

class ImageAssetManager {
  // 图片资源的基础路径
  static const String _basePath = 'assets/images/';
  
  // 不同密度的后缀
  static const Map<double, String> _densitySuffixes = {
    1.0: '',           // mdpi (baseline)
    1.5: '@1.5x',      // hdpi
    2.0: '@2x',        // xhdpi
    3.0: '@3x',        // xxhdpi
    4.0: '@4x',        // xxxhdpi
  };

  // 获取适合当前设备密度的图片路径
  static String getImagePath(String imageName, BuildContext context) {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final bestDensity = _getBestDensity(pixelRatio);
    final suffix = _densitySuffixes[bestDensity] ?? '';
    
    // 分离文件名和扩展名
    final lastDotIndex = imageName.lastIndexOf('.');
    if (lastDotIndex == -1) {
      return '$_basePath$imageName$suffix';
    }
    
    final nameWithoutExt = imageName.substring(0, lastDotIndex);
    final extension = imageName.substring(lastDotIndex);
    
    return '$_basePath$nameWithoutExt$suffix$extension';
  }

  // 根据设备像素比选择最佳密度
  static double _getBestDensity(double pixelRatio) {
    final densities = _densitySuffixes.keys.toList()..sort();
    
    // 如果像素比小于等于1.0，使用基础密度
    if (pixelRatio <= 1.0) return 1.0;
    
    // 找到最接近且不小于当前像素比的密度
    for (final density in densities) {
      if (density >= pixelRatio) {
        return density;
      }
    }
    
    // 如果都小于当前像素比，返回最高密度
    return densities.last;
  }

  // 响应式图片组件
  static Widget responsiveImage(
    String imageName,
    BuildContext context, {
    double? width,
    double? height,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    Color? color,
    BlendMode? colorBlendMode,
    Widget? errorWidget,
    Widget? loadingWidget,
  }) {
    final imagePath = getImagePath(imageName, context);
    
    return ResponsiveBuilder(
      builder: (context, screenType) {
        double? responsiveWidth = width;
        double? responsiveHeight = height;
        
        // 根据屏幕类型调整尺寸
        if (width != null) {
          responsiveWidth = ResponsiveUtils.responsive<double>(
            context,
            mobile: width,
            tablet: width * 1.1,
            desktop: width * 1.2,
          );
        }
        
        if (height != null) {
          responsiveHeight = ResponsiveUtils.responsive<double>(
            context,
            mobile: height,
            tablet: height * 1.1,
            desktop: height * 1.2,
          );
        }
        
        return Image.asset(
          imagePath,
          width: responsiveWidth,
          height: responsiveHeight,
          fit: fit,
          alignment: alignment,
          semanticLabel: semanticLabel,
          excludeFromSemantics: excludeFromSemantics,
          color: color,
          colorBlendMode: colorBlendMode,
          errorBuilder: errorWidget != null 
            ? (context, error, stackTrace) => errorWidget
            : (context, error, stackTrace) => _buildErrorWidget(context, imageName),
          frameBuilder: loadingWidget != null
            ? (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return frame == null ? loadingWidget : child;
              }
            : null,
        );
      },
    );
  }

  // 默认错误组件
  static Widget _buildErrorWidget(BuildContext context, String imageName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[600],
        size: ResponsiveUtils.responsiveIconSize(context, 24),
      ),
    );
  }

  // 预加载图片
  static Future<void> preloadImage(String imageName, BuildContext context) async {
    final imagePath = getImagePath(imageName, context);
    await precacheImage(AssetImage(imagePath), context);
  }

  // 批量预加载图片
  static Future<void> preloadImages(List<String> imageNames, BuildContext context) async {
    final futures = imageNames.map((name) => preloadImage(name, context));
    await Future.wait(futures);
  }

  // 获取响应式图标尺寸
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    return ResponsiveUtils.responsiveIconSize(context, baseSize);
  }

  // 响应式头像组件
  static Widget responsiveAvatar(
    String? imageName,
    BuildContext context, {
    required double radius,
    Color? backgroundColor,
    Widget? placeholder,
    String? fallbackText,
  }) {
    final responsiveRadius = ResponsiveUtils.responsive<double>(
      context,
      mobile: radius,
      tablet: radius * 1.1,
      desktop: radius * 1.2,
    );

    if (imageName == null || imageName.isEmpty) {
      return CircleAvatar(
        radius: responsiveRadius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        child: placeholder ?? 
          (fallbackText != null 
            ? Text(
                fallbackText,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, radius * 0.6),
                  fontWeight: FontWeight.w500,
                ),
              )
            : Icon(
                Icons.person,
                size: ResponsiveUtils.responsiveIconSize(context, radius * 0.8),
                color: Colors.grey[600],
              )),
      );
    }

    return CircleAvatar(
      radius: responsiveRadius,
      backgroundColor: backgroundColor,
      backgroundImage: AssetImage(getImagePath(imageName, context)),
      onBackgroundImageError: (exception, stackTrace) {
        // 图片加载失败时的处理
        // 头像图片加载失败
      },
      child: placeholder,
    );
  }

  // 响应式卡片图片
  static Widget responsiveCardImage(
    String imageName,
    BuildContext context, {
    double? aspectRatio,
    BorderRadius? borderRadius,
    BoxFit fit = BoxFit.cover,
    Widget? overlay,
  }) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final cardBorderRadius = borderRadius ?? BorderRadius.circular(
          ResponsiveUtils.responsive<double>(
            context,
            mobile: 12.0,
            tablet: 16.0,
            desktop: 20.0,
          )
        );

        return ClipRRect(
          borderRadius: cardBorderRadius,
          child: AspectRatio(
            aspectRatio: aspectRatio ?? 16/9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                responsiveImage(
                  imageName,
                  context,
                  fit: fit,
                ),
                if (overlay != null) overlay,
              ],
            ),
          ),
        );
      },
    );
  }

  // 响应式背景图片容器
  static Widget responsiveBackgroundImage(
    String imageName,
    BuildContext context, {
    required Widget child,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
    Color? overlayColor,
    double? overlayOpacity,
  }) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(getImagePath(imageName, context)),
          fit: fit,
          alignment: alignment,
          colorFilter: overlayColor != null 
            ? ColorFilter.mode(
                overlayColor.withOpacity(overlayOpacity ?? 0.5),
                BlendMode.overlay,
              )
            : null,
        ),
      ),
      child: child,
    );
  }

  // 检查图片是否存在
  static Future<bool> imageExists(String imageName, BuildContext context) async {
    try {
      final imagePath = getImagePath(imageName, context);
      await AssetImage(imagePath).resolve(const ImageConfiguration());
      return true;
    } catch (e) {
      return false;
    }
  }

  // 获取图片信息
  static Future<Size?> getImageSize(String imageName, BuildContext context) async {
    try {
      final imagePath = getImagePath(imageName, context);
      final imageStream = AssetImage(imagePath).resolve(const ImageConfiguration());
      final completer = Completer<Size?>();
      
      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
        imageStream.removeListener(listener);
      }, onError: (dynamic exception, StackTrace? stackTrace) {
        completer.complete(null);
        imageStream.removeListener(listener);
      });
      
      imageStream.addListener(listener);
      return await completer.future;
    } catch (e) {
      return null;
    }
  }
} 