import 'package:flutter/material.dart';
import 'responsive_utils.dart';

class ResponsiveTestUtils {
  // 模拟设备配置
  static const Map<String, DeviceConfig> deviceConfigs = {
    // iPhone 设备
    'iPhone SE': DeviceConfig(
      name: 'iPhone SE',
      width: 375,
      height: 667,
      devicePixelRatio: 2.0,
      screenType: ScreenType.mobile,
    ),
    'iPhone 12': DeviceConfig(
      name: 'iPhone 12',
      width: 390,
      height: 844,
      devicePixelRatio: 3.0,
      screenType: ScreenType.mobile,
    ),
    'iPhone 12 Pro Max': DeviceConfig(
      name: 'iPhone 12 Pro Max',
      width: 428,
      height: 926,
      devicePixelRatio: 3.0,
      screenType: ScreenType.mobile,
    ),
    'iPhone 16 Pro Max': DeviceConfig(
      name: 'iPhone 16 Pro Max',
      width: 440,
      height: 956,
      devicePixelRatio: 3.0,
      screenType: ScreenType.mobile,
    ),
    
    // iPad 设备
    'iPad': DeviceConfig(
      name: 'iPad',
      width: 768,
      height: 1024,
      devicePixelRatio: 2.0,
      screenType: ScreenType.tablet,
    ),
    'iPad Pro 11"': DeviceConfig(
      name: 'iPad Pro 11"',
      width: 834,
      height: 1194,
      devicePixelRatio: 2.0,
      screenType: ScreenType.tablet,
    ),
    'iPad Pro 12.9"': DeviceConfig(
      name: 'iPad Pro 12.9"',
      width: 1024,
      height: 1366,
      devicePixelRatio: 2.0,
      screenType: ScreenType.tablet,
    ),
    
    // 桌面设备
    'MacBook Air': DeviceConfig(
      name: 'MacBook Air',
      width: 1280,
      height: 800,
      devicePixelRatio: 2.0,
      screenType: ScreenType.desktop,
    ),
    'MacBook Pro 16"': DeviceConfig(
      name: 'MacBook Pro 16"',
      width: 1512,
      height: 982,
      devicePixelRatio: 2.0,
      screenType: ScreenType.desktop,
    ),
  };

  // 创建设备模拟器
  static Widget createDeviceSimulator({
    required String deviceName,
    required Widget child,
    bool showFrame = true,
  }) {
    final config = deviceConfigs[deviceName];
    if (config == null) {
      throw ArgumentError('Unknown device: $deviceName');
    }

    return DeviceSimulator(
      config: config,
      child: child,
      showFrame: showFrame,
    );
  }

  // 响应式测试套件
  static Widget createTestSuite({
    required Widget Function(BuildContext context) builder,
    List<String>? testDevices,
  }) {
    final devices = testDevices ?? deviceConfigs.keys.toList();
    
    return ResponsiveTestSuite(
      devices: devices,
      builder: builder,
    );
  }

  // 生成测试报告
  static Map<String, TestResult> generateTestReport(
    BuildContext context,
    Widget Function(BuildContext context) builder,
  ) {
    final results = <String, TestResult>{};
    
    for (final deviceName in deviceConfigs.keys) {
      final config = deviceConfigs[deviceName]!;
      results[deviceName] = _testDevice(context, config, builder);
    }
    
    return results;
  }

  // 测试单个设备
  static TestResult _testDevice(
    BuildContext context,
    DeviceConfig config,
    Widget Function(BuildContext context) builder,
  ) {
    try {
      // 创建模拟环境
      final mediaQuery = MediaQuery.of(context).copyWith(
        size: Size(config.width, config.height),
        devicePixelRatio: config.devicePixelRatio,
      );
      
      // 验证响应式组件
      final testContext = _MockBuildContext(mediaQuery);
      final screenType = ResponsiveUtils.getScreenType(testContext);
      
      return TestResult(
        deviceName: config.name,
        screenType: screenType,
        expectedScreenType: config.screenType,
        isResponsive: screenType == config.screenType,
        fontScale: ResponsiveUtils.responsiveFontSize(testContext, 16.0) / 16.0,
        spacingScale: ResponsiveUtils.responsiveSpacing(testContext, 16.0) / 16.0,
        iconScale: ResponsiveUtils.responsiveIconSize(testContext, 24.0) / 24.0,
      );
    } catch (e) {
      return TestResult(
        deviceName: config.name,
        screenType: ScreenType.mobile,
        expectedScreenType: config.screenType,
        isResponsive: false,
        error: e.toString(),
      );
    }
  }

  // 验证字体缩放
  static bool validateFontScaling(BuildContext context) {
    final devices = ['iPhone SE', 'iPad', 'MacBook Air'];
    final results = <double>[];
    
    for (final deviceName in devices) {
      final config = deviceConfigs[deviceName]!;
      final mediaQuery = MediaQuery.of(context).copyWith(
        size: Size(config.width, config.height),
        devicePixelRatio: config.devicePixelRatio,
      );
      final testContext = _MockBuildContext(mediaQuery);
      results.add(ResponsiveUtils.responsiveFontSize(testContext, 16.0));
    }
    
    // 验证字体大小递增
    return results[0] <= results[1] && results[1] <= results[2];
  }

  // 验证断点设置
  static bool validateBreakpoints(BuildContext context) {
    final testCases = [
      (500.0, ScreenType.mobile),
      (700.0, ScreenType.tablet),
      (1000.0, ScreenType.desktop),
    ];
    
    for (final (width, expectedType) in testCases) {
      final mediaQuery = MediaQuery.of(context).copyWith(
        size: Size(width, 800),
      );
      final testContext = _MockBuildContext(mediaQuery);
      final actualType = ResponsiveUtils.getScreenType(testContext);
      
      if (actualType != expectedType) {
        return false;
      }
    }
    
    return true;
  }

  // 创建调试覆盖层
  static Widget createDebugOverlay({
    required Widget child,
    bool showGrid = true,
    bool showBreakpoints = true,
    bool showDimensions = true,
  }) {
    return Builder(
      builder: (context) {
        return Stack(
          children: [
            child,
            if (showGrid) _buildGrid(context),
            if (showBreakpoints) _buildBreakpointIndicator(context),
            if (showDimensions) _buildDimensionDisplay(context),
          ],
        );
      },
    );
  }

  // 构建网格
  static Widget _buildGrid(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(
        gridSize: ResponsiveUtils.responsiveSpacing(context, 8.0),
        color: Colors.red.withOpacity(0.1),
      ),
    );
  }

  // 构建断点指示器
  static Widget _buildBreakpointIndicator(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    final color = switch (screenType) {
      ScreenType.mobile => Colors.green,
      ScreenType.tablet => Colors.orange,
      ScreenType.desktop => Colors.blue,
    };

    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          screenType.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 构建尺寸显示
  static Widget _buildDimensionDisplay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${size.width.toInt()} x ${size.height.toInt()}\n${pixelRatio}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// 设备配置
class DeviceConfig {
  final String name;
  final double width;
  final double height;
  final double devicePixelRatio;
  final ScreenType screenType;

  const DeviceConfig({
    required this.name,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    required this.screenType,
  });
}

// 测试结果
class TestResult {
  final String deviceName;
  final ScreenType screenType;
  final ScreenType expectedScreenType;
  final bool isResponsive;
  final double? fontScale;
  final double? spacingScale;
  final double? iconScale;
  final String? error;

  const TestResult({
    required this.deviceName,
    required this.screenType,
    required this.expectedScreenType,
    required this.isResponsive,
    this.fontScale,
    this.spacingScale,
    this.iconScale,
    this.error,
  });

  @override
  String toString() {
    if (error != null) {
      return '$deviceName: ERROR - $error';
    }
    
    return '$deviceName: ${isResponsive ? 'PASS' : 'FAIL'} '
           '(${screenType.name} vs ${expectedScreenType.name}) '
           'Font: ${fontScale?.toStringAsFixed(2)} '
           'Spacing: ${spacingScale?.toStringAsFixed(2)} '
           'Icon: ${iconScale?.toStringAsFixed(2)}';
  }
}

// 设备模拟器组件
class DeviceSimulator extends StatelessWidget {
  final DeviceConfig config;
  final Widget child;
  final bool showFrame;

  const DeviceSimulator({
    super.key,
    required this.config,
    required this.child,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(config.width, config.height),
        devicePixelRatio: config.devicePixelRatio,
      ),
      child: SizedBox(
        width: config.width,
        height: config.height,
        child: child,
      ),
    );

    if (showFrame) {
      content = Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return Column(
      children: [
        Text(
          config.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }
}

// 响应式测试套件
class ResponsiveTestSuite extends StatelessWidget {
  final List<String> devices;
  final Widget Function(BuildContext context) builder;

  const ResponsiveTestSuite({
    super.key,
    required this.devices,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: devices.map((deviceName) {
          return ResponsiveTestUtils.createDeviceSimulator(
            deviceName: deviceName,
            child: builder(context),
          );
        }).toList(),
      ),
    );
  }
}

// 网格绘制器
class GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  GridPainter({required this.gridSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // 绘制垂直线
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 绘制水平线
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 模拟BuildContext (仅用于测试)
class _MockBuildContext implements BuildContext {
  final MediaQueryData mediaQueryData;

  _MockBuildContext(this.mediaQueryData);

  @override
  MediaQueryData dependOnInheritedWidgetOfExactType<MediaQuery>() => mediaQueryData;

  // 其他BuildContext方法的空实现
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
} 