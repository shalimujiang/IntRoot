import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import '../models/announcement_model.dart';
import '../themes/app_theme.dart';

class UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    required this.currentVersion,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with TickerProviderStateMixin {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accentColor = Colors.teal;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: AlertDialog(
                backgroundColor: dialogColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: EdgeInsets.zero,
                content: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 升级图标和标题
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 600 + (200 * 0).round()),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withOpacity(0.8),
                                      accentColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
            
                        const SizedBox(height: 20),
                        
                        // 标题和版本号 - 带动画
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 600 + (200 * 1).round()),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Column(
                                  children: [
                                    Text(
                                      '发现新版本',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'v${widget.versionInfo.versionName}',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // 更新内容 - 带动画
                        if (widget.versionInfo.releaseNotes.isNotEmpty) ...[
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 600 + (200 * 2).round()),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.versionInfo.releaseNotes.join('\n'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                        height: 1.4,
                                      ),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 强制更新提示 - 带动画
                        if (widget.versionInfo.forceUpdate) ...[
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 600 + (200 * 3).round()),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.shade200, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_rounded,
                                          color: Colors.red.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '此为重要更新，必须更新后才能继续使用',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 下载进度条 - 带动画
                        if (_isDownloading) ...[
                          AnimatedBuilder(
                            animation: _progressAnimationController,
                            builder: (context, child) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '正在下载...',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${(_downloadProgress * 100).toInt()}%',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _downloadProgress,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 按钮区域 - 带动画
                        TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 600 + (200 * 4).round()),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Row(
                                  children: [
                                    if (!widget.versionInfo.forceUpdate && !_isDownloading)
                                      Expanded(
                                        child: Container(
                                          height: 48,
                                          margin: const EdgeInsets.only(right: 8),
                                          child: OutlinedButton(
                                            onPressed: () => Navigator.pop(context),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.grey.shade400, width: 1),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              backgroundColor: Colors.transparent,
                                            ),
                                            child: Text(
                                              '稍后更新',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        margin: EdgeInsets.only(
                                          left: (!widget.versionInfo.forceUpdate && !_isDownloading) ? 8 : 0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isDownloading ? null : _handleUpdate,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isDownloading ? Colors.grey.shade400 : accentColor,
                                            foregroundColor: Colors.white,
                                            elevation: _isDownloading ? 0 : 2,
                                            shadowColor: accentColor.withOpacity(0.3),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (!_isDownloading) ...[
                                                const Icon(
                                                  Icons.download_rounded,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              if (_isDownloading)
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                ),
                                              Text(
                                                _isDownloading ? '下载中...' : '立即更新',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 智能更新处理逻辑
  Future<void> _handleUpdate() async {
    print('UpdateDialog: 点击立即更新按钮');
    
    // 获取下载链接
    String? url = widget.versionInfo.downloadUrls['download'] ?? 
                 widget.versionInfo.downloadUrls['android'] ?? 
                 widget.versionInfo.downloadUrls['ios'];
    
    if (url == null || url.isEmpty) {
      print('UpdateDialog: 更新链接为空或无效');
      return;
    }

    print('UpdateDialog: 准备处理更新链接 - $url');

    // 判断是否为直链
    if (_isDirectDownloadLink(url)) {
      // 直链 - 显示进度条下载
      await _downloadUpdate(url);
    } else {
      // 非直链 - 跳转到外部应用
      await _openExternalLink(url);
    }
  }

  // 判断是否为直链
  bool _isDirectDownloadLink(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    
    // 检查文件扩展名
    return path.endsWith('.apk') || 
           path.endsWith('.ipa') || 
           path.endsWith('.zip') ||
           path.endsWith('.dmg') ||
           path.contains('download');
  }

  // 下载更新文件
  Future<void> _downloadUpdate(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // 启动进度动画
    _progressAnimationController.forward();

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // 模拟下载进度（实际项目中应该使用流式下载）
        for (int i = 0; i <= 100; i += 5) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            setState(() {
              _downloadProgress = i / 100.0;
            });
          }
        }
        
        // 下载完成后的处理
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          
          // 重置进度动画
          _progressAnimationController.reset();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('下载完成！请安装更新包'),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          if (!widget.versionInfo.forceUpdate) {
            Navigator.pop(context);
          }
        }
      } else {
        throw Exception('下载失败：HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('UpdateDialog: 下载异常 - $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        
        // 重置进度动画
        _progressAnimationController.reset();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 打开外部链接
  Future<void> _openExternalLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      final bool canLaunch = await canLaunchUrl(uri);
      
      if (canLaunch) {
        final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (launched && !widget.versionInfo.forceUpdate) {
          Navigator.pop(context);
        }
      } else {
        throw Exception('无法打开链接');
      }
    } catch (e) {
      print('UpdateDialog: 打开链接异常 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开链接失败：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
} 