import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

/// 基于WebView的高性能图片生成工具
/// 
/// 优势：
/// 1. 利用浏览器成熟的渲染引擎
/// 2. CSS样式更灵活强大
/// 3. 支持复杂布局和动画
/// 4. 渲染性能优秀
class WebViewShareUtils {
  static WebViewController? _controller;
  static bool _isInitialized = false;

  /// 初始化WebView控制器
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (kDebugMode) print('WebView开始加载: $url');
          },
          onPageFinished: (String url) {
            if (kDebugMode) print('WebView加载完成: $url');
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) print('WebView加载错误: ${error.description}');
          },
        ),
      );
    
    _isInitialized = true;
  }

  /// 生成分享图片 - WebView版本
  static Future<Uint8List?> generateImageWithWebView({
    required String content,
    required DateTime timestamp,
    required ShareTemplate template,
    List<String>? imagePaths,
    String? baseUrl,
    String? token,
    String? username,
    ValueChanged<double>? onProgress,
    double quality = 0.9,
    Size? size,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    onProgress?.call(0.0);

    try {
      // 1. 生成HTML模板
      final htmlContent = _generateHtmlTemplate(
        content: content,
        timestamp: timestamp,
        template: template,
        imagePaths: imagePaths,
        baseUrl: baseUrl,
        token: token,
        username: username,
        size: size ?? const Size(600, 800),
      );

      onProgress?.call(0.2);

      // 2. 加载HTML到WebView
      await _controller!.loadHtmlString(htmlContent);
      
      // 等待页面完全渲染
      await Future.delayed(const Duration(milliseconds: 1500));

      onProgress?.call(0.6);

      // 3. 执行JavaScript截屏
      final screenshotJs = '''
        function captureElement() {
          const element = document.getElementById('share-container');
          if (!element) return null;
          
          // 使用html2canvas库截图（需要预先注入）
          return html2canvas(element, {
            backgroundColor: '#ffffff',
            scale: ${quality * 2},
            useCORS: true,
            allowTaint: false,
            logging: false,
            width: element.offsetWidth,
            height: element.offsetHeight
          }).then(canvas => {
            return canvas.toDataURL('image/png', $quality);
          });
        }
        captureElement();
      ''';

      final result = await _controller!.runJavaScriptReturningResult(screenshotJs);

      onProgress?.call(0.8);

      if (result != null) {
        // 4. 转换base64数据为Uint8List
        final base64Data = result.toString().split(',')[1];
        final bytes = base64Decode(base64Data);

        onProgress?.call(1.0);
        return bytes;
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('WebView生成图片失败: $e');
      return null;
    }
  }

  /// 生成HTML模板
  static String _generateHtmlTemplate({
    required String content,
    required DateTime timestamp,
    required ShareTemplate template,
    List<String>? imagePaths,
    String? baseUrl,
    String? token,
    String? username,
    required Size size,
  }) {
    final cssStyles = _generateCssStyles(template, size);
    final bodyContent = _generateBodyContent(content, timestamp, imagePaths, username);

    return '''
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>分享图片</title>
        <style>$cssStyles</style>
        <script src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>
    </head>
    <body>
        <div id="share-container" class="share-container template-${template.name}">
            $bodyContent
        </div>
    </body>
    </html>
    ''';
  }

  /// 生成CSS样式
  static String _generateCssStyles(ShareTemplate template, Size size) {
    return '''
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
      }
      
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
        line-height: 1.6;
        color: #333;
        background: transparent;
        overflow: hidden;
      }
      
      .share-container {
        width: ${size.width}px;
        height: ${size.height}px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        padding: 32px;
        position: relative;
        overflow: hidden;
      }
      
      .template-simple {
        background: #ffffff;
      }
      
      .template-card {
        background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
      }
      
      .template-gradient {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      }
      
      .template-diary {
        background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
      }
      
      .content-card {
        background: rgba(255, 255, 255, 0.95);
        border-radius: 20px;
        padding: 32px;
        max-width: 90%;
        backdrop-filter: blur(10px);
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.2);
      }
      
      .content-text {
        font-size: 18px;
        line-height: 1.8;
        color: #2c3e50;
        margin-bottom: 24px;
        word-break: break-all;
      }
      
      .content-images {
        display: grid;
        gap: 16px;
        margin-bottom: 24px;
      }
      
      .content-images.single {
        grid-template-columns: 1fr;
      }
      
      .content-images.multiple {
        grid-template-columns: repeat(2, 1fr);
      }
      
      .content-image {
        border-radius: 12px;
        overflow: hidden;
        max-width: 100%;
        height: auto;
        object-fit: cover;
        transition: transform 0.3s ease;
      }
      
      .timestamp {
        font-size: 14px;
        color: #7f8c8d;
        text-align: right;
        margin-top: auto;
      }
      
      .brand {
        position: absolute;
        bottom: 20px;
        right: 20px;
        font-size: 12px;
        color: rgba(255, 255, 255, 0.7);
      }
      
      @media (max-width: 600px) {
        .share-container {
          padding: 24px;
        }
        
        .content-card {
          padding: 24px;
        }
        
        .content-text {
          font-size: 16px;
        }
      }
      
      /* 动画效果 */
      .fade-in {
        animation: fadeIn 0.6s ease-out;
      }
      
      @keyframes fadeIn {
        from {
          opacity: 0;
          transform: translateY(20px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }
    ''';
  }

  /// 生成HTML内容
  static String _generateBodyContent(
    String content,
    DateTime timestamp,
    List<String>? imagePaths,
    String? username,
  ) {
    final formattedTime = _formatTimestamp(timestamp);
    final processedContent = _processContentForHtml(content);
    final imagesHtml = _generateImagesHtml(imagePaths);

    return '''
      <div class="content-card fade-in">
        <div class="content-text">$processedContent</div>
        $imagesHtml
        <div class="timestamp">$formattedTime</div>
      </div>
      <div class="brand">Made with ❤️ by ${username ?? 'MoMing Notes'}</div>
    ''';
  }

  /// 处理内容为HTML格式
  static String _processContentForHtml(String content) {
    return content
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // 移除图片语法
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), '<strong>\$1</strong>') // 粗体
        .replaceAll(RegExp(r'\*(.*?)\*'), '<em>\$1</em>') // 斜体
        .replaceAll(RegExp(r'`(.*?)`'), '<code>\$1</code>'); // 代码
  }

  /// 生成图片HTML
  static String _generateImagesHtml(List<String>? imagePaths) {
    if (imagePaths == null || imagePaths.isEmpty) {
      return '';
    }

    final imageClass = imagePaths.length == 1 ? 'single' : 'multiple';
    final imagesHtml = imagePaths
        .map((path) => '<img class="content-image" src="$path" alt="图片" loading="lazy">')
        .join('\n');

    return '''
      <div class="content-images $imageClass">
        $imagesHtml
      </div>
    ''';
  }

  /// 格式化时间戳
  static String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}年${timestamp.month}月${timestamp.day}日';
  }

  /// 销毁WebView资源
  static void dispose() {
    _controller = null;
    _isInitialized = false;
  }
}

/// 简化的模板枚举
enum ShareTemplate {
  simple,
  card,
  gradient,
  diary,
} 