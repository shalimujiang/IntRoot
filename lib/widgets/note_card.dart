import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/local_reference_service.dart';
import '../utils/image_utils.dart';
import '../utils/share_utils.dart';
import '../utils/network_utils.dart';
import '../utils/snackbar_utils.dart';
import '../utils/image_cache_manager.dart'; // 🔥 添加长期缓存管理器
import 'ios_datetime_picker.dart';
import 'permission_guide_dialog.dart';
import '../themes/app_theme.dart';
import 'share_image_preview_screen.dart';

// 辅助类用于解析内容中的标签和引用
class _ParseMatch {
  final int start;
  final int end;
  final String type; // 'tag' or 'reference'
  final String content;

  _ParseMatch(this.start, this.end, this.type, this.content);
}

class NoteCard extends StatefulWidget {
  final Note note; // 🚀 直接传递完整Note对象，避免查找
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const NoteCard({
    Key? key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
  }) : super(key: key);
  
  // 🚀 便捷访问属性
  String get content => note.content;
  DateTime get timestamp => note.updatedAt;
  List<String> get tags => note.tags;
  bool get isPinned => note.isPinned;
  String get id => note.id;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  static const int _maxLines = 6;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  static const TextStyle _contentStyle = TextStyle(
    fontSize: 14.0,
    height: 1.5,
    letterSpacing: 0.2,
    color: AppTheme.textPrimaryColor,
  );
  
  static const TextStyle _timestampStyle = TextStyle(
    fontSize: 12.0,
    color: AppTheme.textTertiaryColor,
  );
  
  static const TextStyle _actionButtonStyle = TextStyle(
    color: AppTheme.primaryColor,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
  );

  // 处理标签和Markdown内容
  Widget _buildContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    
    // 🚀 从resourceList和content中提取图片链接（优化：直接使用传入的Note对象）
    List<String> imagePaths = [];
    
    // 从resourceList中获取图片资源（无需查找，直接使用）
    for (var resource in widget.note.resourceList) {
      final uid = resource['uid'] as String?;
      if (uid != null) {
        imagePaths.add('/o/r/$uid');
      }
    }
    
    // 然后从content中提取Markdown格式的图片（兼容性处理）
    final RegExp imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final imageMatches = imageRegex.allMatches(widget.content);
    
    for (var match in imageMatches) {
      final path = match.group(1) ?? '';
      if (path.isNotEmpty && !imagePaths.contains(path)) {
        imagePaths.add(path);
        // if (kDebugMode) print('NoteCard: 从content添加图片: $path');
      }
    }
    
    // if (kDebugMode) print('NoteCard: 最终图片路径列表: $imagePaths');
    
    // 将图片Markdown代码从内容中移除
    String contentWithoutImages = widget.content;
    for (var match in imageMatches) {
      contentWithoutImages = contentWithoutImages.replaceAll(match.group(0) ?? '', '');
    }
    contentWithoutImages = contentWithoutImages.trim();
    
    // 检查是否有文本内容
    bool hasTextContent = contentWithoutImages.isNotEmpty;

    // 检查文本是否需要展开按钮
    bool needsExpansion = _contentMightOverflow(contentWithoutImages);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        
        // 计算图片网格尺寸
        final double spacing = 4.0;
        final double imageWidth = (availableWidth - spacing * 2) / 3;
        final int imageCount = imagePaths.length > 9 ? 9 : imagePaths.length;
        final int rowsNeeded = ((imageCount - 1) ~/ 3 + 1).clamp(0, 3);
        final double gridHeight = rowsNeeded * imageWidth + (rowsNeeded - 1) * spacing;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTextContent)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: _isExpanded ? double.infinity : (6 * _contentStyle.height! * 14.0),
                    ),
                    child: _buildRichContent(contentWithoutImages),
                  ),
                  if (needsExpansion)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? '收起' : '展开',
                              style: TextStyle(
                                color: isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16,
                              color: isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              
            if (imagePaths.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: hasTextContent ? 8.0 : 0),
                child: SizedBox(
                  width: availableWidth,
                  height: gridHeight,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    cacheExtent: 500, // 🚀 预加载缓存（抖音方案）
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: imageCount,
                    itemBuilder: (context, index) {
                      if (index == 8 && imagePaths.length > 9) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildUniformImageItem(imagePaths[index]),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showAllImages(imagePaths),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${imagePaths.length - 8}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return _buildUniformImageItem(imagePaths[index]);
                    },
                  ),
                ),
              ),
          ],
        );
      }
    );
  }

  // 检查文本是否可能超过最大行数
  bool _contentMightOverflow(String content) {
    // 根据内容长度和换行符数量估算可能超过的行数
    int newlineCount = '\n'.allMatches(content).length;
    int estimatedLines = (content.length / 40).ceil() + newlineCount; // 假设每行平均40个字符
    return estimatedLines > 6;
  }

  // 构建富文本内容
  Widget _buildRichContent(String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? (Colors.grey[400] ?? Colors.grey) : Color(0xFF666666);
    final codeBgColor = isDarkMode ? Color(0xFF2C2C2C) : Color(0xFFF5F5F5);
    
    // 解析内容，包括标签和引用
    List<Widget> contentWidgets = _parseContentWithTagsAndReferences(content, textColor, secondaryTextColor, codeBgColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: contentWidgets,
            ),
          ),
        );
      },
    );
  }

  // 解析内容，同时处理标签和引用
  List<Widget> _parseContentWithTagsAndReferences(String content, Color textColor, Color secondaryTextColor, Color codeBgColor) {
    List<Widget> widgets = [];
    
    // 定义正则表达式
    final tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    // 引用正则：匹配所有的 [内容]
    final referenceRegex = RegExp(r'\[([^\]]+)\]');
    
    // 分段处理内容
    int lastIndex = 0;
    final allMatches = <_ParseMatch>[];
    
    // 收集所有匹配
    for (final match in tagRegex.allMatches(content)) {
      allMatches.add(_ParseMatch(match.start, match.end, 'tag', match.group(1)!));
    }
    for (final match in referenceRegex.allMatches(content)) {
      allMatches.add(_ParseMatch(match.start, match.end, 'reference', match.group(1)!));
    }
    
    // 按位置排序
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    for (final match in allMatches) {
      // 添加匹配前的普通文本
      if (match.start > lastIndex) {
        final plainText = content.substring(lastIndex, match.start);
        if (plainText.isNotEmpty) {
          widgets.add(_buildMarkdownText(plainText, textColor, secondaryTextColor, codeBgColor));
        }
      }
      
      // 添加特殊格式的组件
      if (match.type == 'tag') {
        widgets.add(_buildTagWidget(match.content));
      } else if (match.type == 'reference') {
        widgets.add(_buildReferenceWidget(match.content));
      }
      
      lastIndex = match.end;
      }
      
    // 添加剩余的普通文本
    if (lastIndex < content.length) {
      final plainText = content.substring(lastIndex);
      if (plainText.isNotEmpty) {
        widgets.add(_buildMarkdownText(plainText, textColor, secondaryTextColor, codeBgColor));
      }
    }
    
    return widgets;
  }

  // 构建标签组件
  Widget _buildTagWidget(String tag) {
    return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
      ),
    );
  }

  // 构建引用组件
  Widget _buildReferenceWidget(String referenceContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        referenceContent,
        style: TextStyle(
          color: Colors.blue,
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
            ),
          ),
        );
  }

  // 构建普通Markdown文本
  Widget _buildMarkdownText(String text, Color textColor, Color secondaryTextColor, Color codeBgColor) {
    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: _contentStyle.copyWith(color: textColor),
        h1: _contentStyle.copyWith(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor),
        h2: _contentStyle.copyWith(fontSize: 18.0, fontWeight: FontWeight.bold, color: textColor),
        h3: _contentStyle.copyWith(fontSize: 16.0, fontWeight: FontWeight.bold, color: textColor),
        code: _contentStyle.copyWith(
          backgroundColor: codeBgColor,
          color: textColor,
          fontFamily: 'monospace',
        ),
        blockquote: _contentStyle.copyWith(
          color: secondaryTextColor,
          fontStyle: FontStyle.italic,
          ),
      ),
      shrinkWrap: true,
      softLineBreak: true,
    );
  }
  
  // 构建统一大小的图片网格
  Widget _buildUniformImageGrid(List<String> imagePaths) {
    final int imageCount = imagePaths.length > 9 ? 9 : imagePaths.length;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double gridWidth = screenWidth * 0.7;
    
    return SizedBox(
      width: gridWidth,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: imageCount,
        itemBuilder: (context, index) {
          if (index == 8 && imagePaths.length > 9) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildUniformImageItem(imagePaths[index]),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAllImages(imagePaths),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+${imagePaths.length - 8}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return _buildUniformImageItem(imagePaths[index]);
        },
      ),
    );
  }
  
  // 构建统一大小的单个图片项
  Widget _buildUniformImageItem(String imagePath) {
    try {
      return GestureDetector(
        onTap: () => _showFullscreenImage(imagePath),
        child: Container(
          width: double.infinity,
          height: 120, // 添加明确的高度
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _buildImageWidget(imagePath, context),
          ),
        ),
      );
    } catch (e) {
              if (kDebugMode) print('Error building image item: $e for path $imagePath');
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey[600])),
      );
    }
  }
  
  // 显示所有图片
  void _showAllImages(List<String> imagePaths) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _AllImagesScreen(imagePaths: imagePaths),
        ),
      );
    } catch (e) {
              if (kDebugMode) print('Error showing all images: $e');
      SnackBarUtils.showError(context, '无法显示图片');
    }
  }
  
  // 显示全屏图片
  void _showFullscreenImage(String imagePath) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _ImageViewerScreen(imagePath: imagePath),
        ),
      );
    } catch (e) {
              if (kDebugMode) print('Error showing fullscreen image: $e');
      SnackBarUtils.showError(context, '无法显示图片');
    }
  }
  
  // 构建图片组件，支持不同类型的图片源
  Widget _buildImageWidget(String imagePath, BuildContext context) {
    try {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        // 🚀 网络图片 - 90天长期缓存（让系统自动优化尺寸）
        return CachedNetworkImage(
          imageUrl: imagePath,
          cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: const Duration(milliseconds: 50),
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: SizedBox(),
          ),
          errorWidget: (context, url, error) {
            // 🔥 离线模式：即使网络失败，也尝试从缓存加载
            return FutureBuilder<File?>(
              future: _getCachedImageFile(url),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[600], size: 20),
                );
              },
            );
          },
        );
      } else if (imagePath.startsWith('/o/r/') || imagePath.startsWith('/file/') || imagePath.startsWith('/resource/')) {
        // Memos服务器资源路径
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        
        // 🔥 构建完整URL（即使退出登录也能访问缓存）
        String fullUrl;
        if (appProvider.resourceService != null) {
          fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
        } else {
          // 退出登录后，尝试从缓存的服务器URL构建
          final serverUrl = appProvider.appConfig.lastServerUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          if (serverUrl.isNotEmpty) {
            fullUrl = '$serverUrl$imagePath';
          } else {
            // 无法构建URL，尝试直接从缓存加载
            return FutureBuilder<File?>(
              future: _findImageInCache(imagePath),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[600], size: 20),
                );
              },
            );
          }
        }
        
        final token = appProvider.user?.token;
        Map<String, String> headers = {};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        
        // 🚀 使用90天长期缓存
        return CachedNetworkImage(
          imageUrl: fullUrl,
          cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
          httpHeaders: headers,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: const Duration(milliseconds: 50),
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: SizedBox(),
          ),
          errorWidget: (context, url, error) {
            // 🔥 离线模式：即使网络失败，也尝试从缓存加载
            return FutureBuilder<File?>(
              future: _getCachedImageFile(fullUrl),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[600], size: 20),
                );
              },
            );
          },
        );
      } else if (imagePath.startsWith('file://')) {
        // 本地文件
        String filePath = imagePath.replaceFirst('file://', '');
        return Image.file(
          File(filePath),
          key: ValueKey(filePath), // 添加key强制刷新
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) print('Local file image error: $error for $filePath');
            // 如果图片文件不存在，尝试触发刷新来获取修复后的路径
            return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
          },
        );
      }
      
      // 默认情况
              // if (kDebugMode) print('NoteCard: 未知图片路径格式: $imagePath');
      return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
    } catch (e) {
              if (kDebugMode) print('Error in _buildImageWidget: $e for $imagePath');
      return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
    }
  }
  
  // 🔥 从缓存获取图片文件（离线模式）
  Future<File?> _getCachedImageFile(String url) async {
    try {
      final fileInfo = await ImageCacheManager.authImageCache.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e) {
      if (kDebugMode) print('获取缓存图片失败: $e');
      return null;
    }
  }
  
  // 🔥 在缓存中查找图片（通过路径片段匹配）
  Future<File?> _findImageInCache(String imagePath) async {
    try {
      // 尝试多个可能的服务器URL前缀
      final possibleUrls = [
        'https://memos.didichou.site$imagePath',
        'http://localhost$imagePath',
      ];
      
      for (final url in possibleUrls) {
        final fileInfo = await ImageCacheManager.authImageCache.getFileFromCache(url);
        if (fileInfo != null) {
          if (kDebugMode) print('找到缓存图片: $url');
          return fileInfo.file;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('查找缓存图片失败: $e');
      return null;
    }
  }
  
  // 根据URI获取适当的ImageProvider
  ImageProvider _getImageProvider(String uriString, BuildContext context) {
    try {
      if (uriString.startsWith('http://') || uriString.startsWith('https://')) {
        // 网络图片
        return NetworkImage(uriString);
      } else if (uriString.startsWith('/o/r/') || uriString.startsWith('/file/') || uriString.startsWith('/resource/')) {
        // Memos服务器资源路径，支持多种路径格式
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.resourceService != null) {
          final fullUrl = appProvider.resourceService!.buildImageUrl(uriString);
          final token = appProvider.user?.token;
          // if (kDebugMode) print('NoteCard: 加载Memos图片 - 原路径: $uriString, URL: $fullUrl, 有Token: ${token != null}');
          if (token != null) {
            return CachedNetworkImageProvider(
              fullUrl, 
              headers: {'Authorization': 'Bearer $token'}
            );
          } else {
            return CachedNetworkImageProvider(fullUrl);
          }
        } else {
          // 如果没有资源服务，尝试使用基础URL
          final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          if (baseUrl.isNotEmpty) {
            final token = appProvider.user?.token;
            final fullUrl = '$baseUrl$uriString';
            // if (kDebugMode) print('NoteCard: 加载Memos图片(fallback) - URL: $fullUrl, 有Token: ${token != null}');
            if (token != null) {
              return CachedNetworkImageProvider(
                fullUrl, 
                headers: {'Authorization': 'Bearer $token'}
              );
            } else {
              return CachedNetworkImageProvider(fullUrl);
            }
          }
        }
        return const AssetImage('assets/images/logo.png');
      } else if (uriString.startsWith('file://')) {
        // 本地文件
        String filePath = uriString.replaceFirst('file://', '');
        return FileImage(File(filePath));
      } else if (uriString.startsWith('resource:')) {
        // 资源图片
        String assetPath = uriString.replaceFirst('resource:', '');
        return AssetImage(assetPath);
      } else {
        // 未知路径格式，记录并使用默认图片
        // if (kDebugMode) print('NoteCard: 未知图片路径格式: $uriString');
        return const AssetImage('assets/images/logo.png');
      }
    } catch (e) {
      if (kDebugMode) print('Error in _getImageProvider: $e');
      return const AssetImage('assets/images/logo.png');
    }
  }

  // 显示更多选项菜单 - iOS风格重新设计
  void _showMoreOptions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => _buildModernMoreOptions(context, isDarkMode),
    );
  }

  Widget _buildModernMoreOptions(BuildContext context, bool isDarkMode) {
    // 🎨 符合现有主题的配色方案
    final primaryColor = AppTheme.primaryColor;
    final primaryLight = AppTheme.primaryLightColor;
    final primaryDark = AppTheme.primaryDarkColor;
        
    final surfaceColor = isDarkMode 
        ? AppTheme.darkCardColor
        : AppTheme.surfaceColor;
        
    final cardColor = isDarkMode 
        ? AppTheme.darkSurfaceColor
        : AppTheme.backgroundColor;
        
    final textPrimary = isDarkMode 
        ? AppTheme.darkTextPrimaryColor
        : AppTheme.textPrimaryColor;
        
    final textSecondary = isDarkMode 
        ? AppTheme.darkTextSecondaryColor
        : AppTheme.textSecondaryColor;
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 🌟 主菜单容器 - 毛玻璃效果
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode 
                          ? Colors.black.withOpacity(0.5)
                          : Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          // 🎯 顶部拖拽指示器
                          Container(
                            margin: const EdgeInsets.only(top: 16, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textSecondary.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          
                          // 📱 标题区域
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.auto_stories,
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '笔记操作',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '选择您要执行的操作',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // 🚀 快速操作区域 - 现代化卡片网格
                          Container(
                            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Column(
                              children: [
                                // 第一行：主要操作
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: Icons.ios_share_rounded,
                                        label: '分享',
                                        subtitle: 'Share',
                                                                                 gradient: [
                                           primaryColor,
                                           primaryDark,
                                         ],
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showShareOptions(context);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: Icons.edit_rounded,
                                        label: '编辑',
                                        subtitle: 'Edit',
                                                                                 gradient: [
                                           AppTheme.warningColor,
                                           const Color(0xFFE67E22),
                                         ],
                                        onTap: () {
                                          Navigator.pop(context);
                                          widget.onEdit();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                        label: widget.isPinned ? '取消置顶' : '置顶',
                                        subtitle: widget.isPinned ? 'Unpin' : 'Pin',
                                                                                 gradient: [
                                           primaryLight,
                                           primaryColor,
                                         ],
                                        onTap: () {
                                          Navigator.pop(context);
                                          widget.onPin();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // 第二行：辅助操作
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: Icons.content_copy_rounded,
                                        label: '复制',
                                        subtitle: 'Copy',
                                                                                 gradient: [
                                           const Color(0xFF8B5CF6),
                                           const Color(0xFF7C3AED),
                                         ],
                                        onTap: () async {
                                          Navigator.pop(context);
                                          await Clipboard.setData(ClipboardData(text: widget.content));
                                          if (context.mounted) {
                                            _showModernSnackBar(context, '内容已复制', Icons.check_circle);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: Icons.link_rounded,
                                        label: '链接',
                                        subtitle: 'Link',
                                                                                 gradient: [
                                           primaryColor,
                                           primaryDark,
                                         ],
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final currentNote = _getCurrentNote();
                                          if (currentNote.isPublic) {
                                            // 已经是公开状态，直接复制链接
                                            _copyShareLinkDirectly();
                                          } else {
                                            // 私有状态，显示权限确认对话框
                                            _showPublicPermissionDialog();
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        context,
                                        icon: Icons.delete_rounded,
                                        label: '删除',
                                        subtitle: 'Delete',
                                                                                 gradient: [
                                           AppTheme.errorColor,
                                           const Color(0xFFD32F2F),
                                         ],
                                        onTap: () {
                                          Navigator.pop(context);
                                          widget.onDelete();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // 📋 详细选项列表
                          Container(
                            margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode 
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildMenuOption(
                                  context,
                                  icon: Icons.account_tree_outlined,
                                  title: "引用详情",
                                  subtitle: "查看笔记引用关系",
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  primaryColor: primaryColor,
                                                                     onTap: () {
                                     Navigator.pop(context);
                                     _showViewReferencesDialog(context);
                                   },
                                  isFirst: true,
                                ),
                                _buildMenuDivider(isDarkMode),
                                _buildReminderMenuOption(
                                  context,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  primaryColor: primaryColor,
                                ),
                                _buildMenuDivider(isDarkMode),
                                _buildVisibilityMenuOption(
                                  context,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  primaryColor: primaryColor,
                                ),
                                _buildMenuDivider(isDarkMode),
                                _buildMenuOption(
                                  context,
                                  icon: Icons.info_outline,
                                  title: "详细信息",
                                  subtitle: "查看创建时间等信息",
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  primaryColor: primaryColor,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showNoteDetails(context);
                                  },
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // ❌ 取消按钮
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  color: surfaceColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 快速操作卡片
  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📋 菜单选项
  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  icon,
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
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

     // 🔍 可见性菜单选项
   Widget _buildVisibilityMenuOption(
     BuildContext context, {
     required Color textPrimary,
     required Color textSecondary,
     required Color primaryColor,
   }) {
     return _buildMenuOption(
       context,
       icon: Icons.visibility,
       title: "分享设置",
       subtitle: "管理笔记可见性",
       textPrimary: textPrimary,
       textSecondary: textSecondary,
       primaryColor: primaryColor,
       onTap: () {
         Navigator.pop(context);
         _showShareOptions(context);
       },
     );
   }

  // ⏰ 提醒菜单选项
  Widget _buildReminderMenuOption(
    BuildContext context, {
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    // 获取当前笔记的提醒时间
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final reminderTime = appProvider.getNoteReminderTime(widget.id);
    
    // 🔥 参考大厂应用：实时检查提醒是否已过期
    // 过期的提醒不显示图标，视为未设置
    final now = DateTime.now();
    final hasValidReminder = reminderTime != null && reminderTime.isAfter(now);
    
    return _buildMenuOption(
      context,
      icon: hasValidReminder ? Icons.alarm : Icons.alarm_add,
      title: hasValidReminder ? "提醒已设置" : "设置提醒",
      subtitle: hasValidReminder 
          ? "点击修改或取消提醒"
          : "设置笔记提醒时间",
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      primaryColor: hasValidReminder ? Colors.orange : primaryColor,
      onTap: () {
        Navigator.pop(context);
        _showReminderDialog(context);
      },
    );
  }

  // 📱 现代化提示条 (已替换为SnackBarUtils)
  void _showModernSnackBar(BuildContext context, String message, IconData icon) {
    // 根据图标类型选择合适的SnackBarUtils方法
    if (icon == Icons.check) {
      SnackBarUtils.showSuccess(context, message);
    } else if (icon == Icons.error) {
      SnackBarUtils.showError(context, message);
    } else if (icon == Icons.info) {
      SnackBarUtils.showInfo(context, message);
    } else if (icon == Icons.warning) {
      SnackBarUtils.showWarning(context, message);
    } else {
      SnackBarUtils.showInfo(context, message);
    }
  }

  // 📏 菜单分割线
  Widget _buildMenuDivider(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            isDarkMode 
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // 📊 笔记详情弹窗
  void _showNoteDetails(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
         final primaryColor = AppTheme.primaryColor;
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
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
                        Icons.info_outline,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '笔记详情',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('创建时间', DateFormat('yyyy年MM月dd日 HH:mm').format(widget.timestamp), textPrimary, textSecondary),
                const SizedBox(height: 16),
                _buildDetailRow('字符数量', '${widget.content.length} 字符', textPrimary, textSecondary),
                const SizedBox(height: 16),
                _buildDetailRow('标签数量', '${widget.tags.length} 个标签', textPrimary, textSecondary),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '关闭',
                        style: TextStyle(
                          color: primaryColor,
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

  // 📋 详情行
  Widget _buildDetailRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ⏰ 显示提醒设置对话框（iOS风格）
  void _showReminderDialog(BuildContext menuContext) async {
    if (!mounted) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentReminderTime = appProvider.getNoteReminderTime(widget.id);
    
    // 如果已有提醒，先显示选项：修改或取消
    if (currentReminderTime != null) {
      if (!mounted) return;
      
      final action = await _showReminderOptionsSheet(context, currentReminderTime);
      
      if (!mounted) return;
      
      // 用户点击了关闭或返回
      if (action == null) return;
      
      // 用户选择取消提醒
      if (action == 'cancel') {
        try {
          await appProvider.cancelNoteReminder(widget.id);
          if (!mounted) return;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      '✅ 已取消提醒',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFFF9800),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '取消失败: $e',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }
        }
        return;
      }
      
      // 用户选择修改提醒时间，继续往下执行
    }
    
    // 🔥 先检查权限，没有权限先显示引导
    if (!mounted) return;
    
    // 检查通知权限
    final notificationService = appProvider.notificationService;
    bool hasPermission = await notificationService.areNotificationsEnabled();
    
    if (!hasPermission) {
      if (!mounted) return;
      if (context.mounted) {
        // 显示权限引导弹窗
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PermissionGuideDialog(),
        );
        
        // 🔥 权限引导后重新检查权限
        if (!mounted) return;
        hasPermission = await notificationService.areNotificationsEnabled();
        
        // 如果还是没有权限，提示用户并返回
        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text('请先开启通知权限才能设置提醒'),
                  ],
                ),
                backgroundColor: Colors.orange.shade600,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } else {
        return;
      }
    }
    
    if (!mounted) return;
    
    // 🔥 修复：确保初始时间不早于最小时间
    final now = DateTime.now();
    DateTime initialTime;
    
    if (currentReminderTime != null && currentReminderTime.isAfter(now)) {
      // 如果已有提醒时间且在未来，使用该时间
      initialTime = currentReminderTime;
    } else {
      // 否则使用1小时后
      initialTime = now.add(const Duration(hours: 1));
    }
    
    final reminderDateTime = await IOSDateTimePicker.show(
      context: context,
      initialDateTime: initialTime,
      minimumDateTime: now,
      maximumDateTime: now.add(const Duration(days: 365)),
    );
    
    // 检查widget是否还存在
    if (!mounted) {
      if (kDebugMode) {
        print('NoteCard: ⚠️ Widget已销毁（时间选择器返回后），停止操作');
      }
      return;
    }
    
    // 用户取消了时间选择
    if (reminderDateTime == null) {
      if (kDebugMode) {
        print('NoteCard: 用户取消了时间选择');
      }
      return;
    }
    
    if (kDebugMode) {
      print('NoteCard: 用户选择的时间: $reminderDateTime');
    }
    
    // 检查时间是否在未来
    if (reminderDateTime.isBefore(DateTime.now())) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  '⚠️ 提醒时间必须在未来',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      }
      return;
    }
    
    // 设置提醒
    try {
      if (kDebugMode) {
        print('NoteCard: 开始设置提醒...');
      }
      
      final success = await appProvider.setNoteReminder(widget.id, reminderDateTime);
      
      if (!mounted) return;
      
      if (!success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text('设置提醒失败，请稍后重试'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // 旧的权限引导代码已被PermissionGuideDialog替代
      /*
      // 以下是旧代码，已注释
      if (!success && false) {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Text('需要开启通知权限'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '为了准时收到笔记提醒，请按以下步骤操作：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📱 小米/红米手机必须开启以下权限：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                          SizedBox(height: 12),
                           Text('🔥 点击下方"应用设置"按钮，然后：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                           SizedBox(height: 10),
                           Text('1️⃣ 通知管理 → 允许通知 ✅', style: TextStyle(fontSize: 13)),
                           SizedBox(height: 6),
                           Text('2️⃣ 通知管理 → 允许横幅通知 ✅ （关键！）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                           SizedBox(height: 6),
                           Text('3️⃣ 通知管理 → 允许锁屏通知 ✅', style: TextStyle(fontSize: 13)),
                           SizedBox(height: 6),
                           Text('4️⃣ 其他权限 → 设置闹钟和提醒 ✅', style: TextStyle(fontSize: 13)),
                           SizedBox(height: 6),
                           Text('5️⃣ 省电策略 → 无限制 ✅', style: TextStyle(fontSize: 13)),
                          SizedBox(height: 10),
                          Divider(color: Colors.orange),
                          SizedBox(height: 10),
                          Text('🔥🔥 关键（必须）：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                          SizedBox(height: 8),
                           Text('6️⃣ 返回手机"设置"主页', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                           SizedBox(height: 6),
                           Text('7️⃣ 搜索"自启动" → 找到InkRoot → 开启✅', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                           SizedBox(height: 6),
                           Text('8️⃣ 搜索"电池优化" → InkRoot → 不限制✅', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '不开启自启动和电池优化，应用关闭后就收不到提醒！',
                              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('稍后'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // 跳转到电池优化设置
                    try {
                      const platform = MethodChannel('com.didichou.inkroot/native_alarm');
                      await platform.invokeMethod('requestBatteryOptimization');
                    } catch (e) {
                      print('无法打开电池优化设置: $e');
                    }
                  },
                  icon: const Icon(Icons.battery_charging_full, size: 20),
                  label: const Text('电池优化', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // 跳转到应用设置
                    try {
                      const platform = MethodChannel('com.didichou.inkroot/native_alarm');
                      await platform.invokeMethod('openAppSettings');
                    } catch (e) {
                      print('无法打开设置: $e');
                    }
                  },
                  icon: const Icon(Icons.settings, size: 20),
                  label: const Text('应用设置', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }
      */
      
      if (kDebugMode) {
        print('NoteCard: ✅ 提醒设置成功！');
      }
      
      if (context.mounted) {
        // 🎉 显示醒目的成功提示（带动画效果）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),  // 🔥 延长显示时间
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✅ 提醒已设置成功！',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '将在 ${DateFormat('MM月dd日 HH:mm', 'zh_CN').format(reminderDateTime)} 准时通知',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            elevation: 6,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('NoteCard: ❌ 设置提醒失败: $e');
      }
      
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '❌ 设置提醒失败',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '错误: $e',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            elevation: 6,
          ),
        );
      }
    }
  }
  
  // 显示提醒选项（修改或取消）
  Future<String?> _showReminderOptionsSheet(BuildContext context, DateTime currentTime) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity( 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 当前提醒时间
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.alarm, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      '当前提醒时间',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN').format(currentTime),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 选项按钮
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF007AFF)),
                title: const Text('修改提醒时间'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('取消提醒', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 显示分享选项菜单
  void _showShareOptions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildIOSStyleShareOptions(context, isDarkMode),
    );
  }

  Widget _buildIOSStyleShareOptions(BuildContext context, bool isDarkMode) {
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final surfaceColor = isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey.shade600;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryTextColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                '分享笔记',
                  style: TextStyle(
                  fontSize: 20,
                    fontWeight: FontWeight.w600,
                  color: textColor,
                  ),
                ),
              ),
            
            // 分享方式选项 - 网格布局
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildShareOptionCard(
                      context,
                      icon: Icons.link_rounded,
                      title: '分享链接',
                      subtitle: '生成分享链接',
                      color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showPublicPermissionDialog();
              },
            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildShareOptionCard(
                      context,
                      icon: Icons.image_rounded,
                      title: '分享图片',
                      subtitle: '生成图片分享',
                      color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _shareImage();
              },
            ),
                  ),
                ],
              ),
            ),
            
            // 快捷分享按钮
            Container(
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '快捷操作',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildQuickShareOption(
                          context,
                          icon: Icons.copy_rounded,
                          title: '复制内容',
                          subtitle: '复制笔记内容到剪贴板',
                          onTap: () async {
                            Navigator.pop(context);
                            await Clipboard.setData(ClipboardData(text: widget.content));
                            if (context.mounted) {
                              SnackBarUtils.showSuccess(context, '内容已复制到剪贴板');
                            }
                          },
                          isFirst: true,
                        ),
                        _buildQuickShareDivider(),
                        _buildQuickShareOption(
                          context,
                          icon: Icons.ios_share_rounded,
                          title: '系统分享',
                          subtitle: '使用系统分享功能',
              onTap: () {
                Navigator.pop(context);
                            Share.share(
                              '📝 InkRoot 笔记分享\n\n${widget.content.length > 200 ? '${widget.content.substring(0, 200)}...' : widget.content}',
                              subject: '来自 InkRoot 的笔记分享',
                            );
                          },
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 笔记预览卡片
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: secondaryTextColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                  Text(
                        '笔记预览',
                    style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                    ),
                  ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.content.length > 100 
                        ? '${widget.content.substring(0, 100)}...' 
                        : widget.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPreviewInfo('${widget.content.length} 字符', textColor, secondaryTextColor),
                      const SizedBox(width: 16),
                      _buildPreviewInfo(DateFormat('MM月dd日 HH:mm').format(widget.timestamp), textColor, secondaryTextColor),
                    ],
                  ),
                ],
              ),
            ),
            
            // 底部安全区域
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
              subtitle,
                    style: TextStyle(
                      fontSize: 12,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final subtitleColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey.shade600;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShareDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 56),
      height: 0.5,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildPreviewInfo(String text, Color textColor, Color secondaryTextColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: secondaryTextColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: secondaryTextColor,
          ),
        ),
      ],
    );
  }

     // 分享链接
  void _shareLink() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 检查用户是否登录
    if (appProvider.user == null || appProvider.user!.token?.isEmpty == true) {
      SnackBarUtils.showWarning(context, '请先登录后再使用分享链接功能');
      return;
    }
    
    // 获取当前笔记的完整信息
    final currentNote = _getCurrentNote();
    
    // 检查笔记的可见性状态
    if (currentNote.isPublic) {
      // 笔记已经是公开状态，直接生成分享链接
      _proceedWithSharing();
    } else {
      // 笔记是私有状态，显示权限确认对话框
      _showPublicPermissionDialog();
    }
  }
   
   // 获取分享URL
   Future<String?> _getShareUrl() async {
     try {
       final appProvider = Provider.of<AppProvider>(context, listen: false);
       final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
      final token = appProvider.user?.token;
       
       if (baseUrl.isEmpty) {
         throw Exception('服务器地址为空');
       }
      
      // 检查系统是否禁用了公开memo
      if (token != null) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/v1/status'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          
          if (response.statusCode == 200) {
            final systemStatus = jsonDecode(response.body);
            final disablePublicMemos = systemStatus['disablePublicMemos'] ?? false;
            
            if (disablePublicMemos) {
              throw Exception('系统管理员已禁用公开分享功能');
            }
          }
                 } catch (e) {
           if (kDebugMode) print('检查系统设置失败: $e');
           // 如果检查失败且包含特定错误信息，直接抛出异常
           if (e.toString().contains('系统管理员已禁用公开分享功能')) {
             rethrow;
           }
           // 如果无法检查系统设置，仍然尝试创建分享链接
         }
       }
       
       // 首先需要将笔记设置为公开，然后获取分享链接
      final uid = await _setMemoPublic();
      if (uid == null) {
         throw Exception('无法将笔记设置为公开');
       }
       
      // 构建公开访问链接，使用返回的UID
       final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/api/v\d+/?$'), '');
      final shareUrl = '$cleanBaseUrl/m/$uid';
       
       return shareUrl;
     } catch (e) {
       if (kDebugMode) print('Error getting share URL: $e');
       return null;
     }
   }
   
   // 显示查看引用对话框
   void _showViewReferencesDialog(BuildContext context) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     final appProvider = Provider.of<AppProvider>(context, listen: false);
     final notes = appProvider.notes;
     
     // 获取当前笔记的信息，包括关系
     final currentNote = notes.firstWhere(
       (note) => note.id.toString() == widget.id.toString(),
       orElse: () => Note(
         id: widget.id.toString(),
         content: widget.content,
         createdAt: widget.timestamp,
         updatedAt: widget.timestamp,
       ),
     );
     
                                // 过滤出所有引用类型的关系，包括正向和反向
    final allReferences = currentNote.relations.where((relation) {
      final type = relation['type'];
      return type == 1 || type == 'REFERENCE' || type == 'REFERENCED_BY'; // 包含所有引用类型
    }).toList();
     
     // 分类引用关系
     final outgoingRefs = <Map<String, dynamic>>[];
     final incomingRefs = <Map<String, dynamic>>[];
     
     for (var relation in allReferences) {
       final type = relation['type'];
       final memoId = relation['memoId']?.toString() ?? '';
       final currentId = widget.id.toString();
       
       if (type == 'REFERENCED_BY') {
         // 这是一个被引用关系，其他笔记引用了当前笔记
         incomingRefs.add(relation);
       } else if (type == 'REFERENCE' || type == 1) {
         // 这是一个引用关系，当前笔记引用了其他笔记
         if (memoId == currentId) {
           outgoingRefs.add(relation);
         }
       }
     }
     
     showDialog(
       context: context,
       builder: (context) => Dialog(
         insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
         backgroundColor: Colors.transparent,
         child: Container(
           decoration: BoxDecoration(
             color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
             borderRadius: BorderRadius.circular(20),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.15),
                 blurRadius: 25,
                 offset: const Offset(0, 10),
               ),
             ],
           ),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               // 标题区域
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                 decoration: BoxDecoration(
                   color: isDarkMode 
                     ? AppTheme.primaryColor.withOpacity(0.08)
                     : AppTheme.primaryColor.withOpacity(0.04),
                   borderRadius: const BorderRadius.only(
                     topLeft: Radius.circular(20),
                     topRight: Radius.circular(20),
                   ),
                 ),
                 child: Column(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: AppTheme.primaryColor.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(50),
                       ),
                       child: Icon(
                         Icons.account_tree_outlined,
                         color: AppTheme.primaryColor,
                         size: 24,
                       ),
                     ),
                     const SizedBox(height: 12),
                     Text(
                       "引用关系",
                       style: TextStyle(
                         fontSize: 20,
                         fontWeight: FontWeight.w600,
                         color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                       ),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       '查看此笔记的所有引用关系',
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         fontSize: 14,
                         color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.7),
                       ),
                     ),
                   ],
                 ),
               ),
               
               // 引用列表
               Container(
                 constraints: const BoxConstraints(maxHeight: 400),
                 padding: const EdgeInsets.all(16),
                 child: allReferences.isEmpty
                   ? Padding(
                       padding: const EdgeInsets.all(32),
                       child: Column(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Colors.grey.shade100,
                               borderRadius: BorderRadius.circular(50),
                             ),
                             child: Icon(
                               Icons.link_off,
                               size: 32,
                               color: Colors.grey.shade400,
                             ),
                           ),
                           const SizedBox(height: 16),
                           Text(
                             '暂无引用关系',
                             style: TextStyle(
                               color: Colors.grey.shade600,
                               fontSize: 16,
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             '在编辑笔记时可以添加引用关系',
                             style: TextStyle(
                               color: Colors.grey.shade500,
                               fontSize: 12,
                             ),
                           ),
                         ],
                       ),
                     )
                   : SingleChildScrollView(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // 引用的笔记部分
                           if (outgoingRefs.isNotEmpty) ...[
                             Padding(
                               padding: const EdgeInsets.only(left: 8, bottom: 8),
                               child: Row(
                                 children: [
                                   Icon(
                                     Icons.north_east,
                                     size: 16,
                                     color: Colors.blue,
                                   ),
                                   const SizedBox(width: 6),
                                   Text(
                                     '引用的笔记 (${outgoingRefs.length})',
                                     style: TextStyle(
                                       fontSize: 14,
                                       fontWeight: FontWeight.w600,
                                       color: Colors.blue,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             ...outgoingRefs.map((relation) => _buildReferenceItem(relation, notes, isDarkMode, true)),
                             const SizedBox(height: 16),
                           ],
                           
                           // 被引用部分
                           if (incomingRefs.isNotEmpty) ...[
                             Padding(
                               padding: const EdgeInsets.only(left: 8, bottom: 8),
                               child: Row(
                                 children: [
                                   Icon(
                                     Icons.north_west,
                                     size: 16,
                                     color: Colors.orange,
                                   ),
                                   const SizedBox(width: 6),
                                   Text(
                                     '被引用 (${incomingRefs.length})',
                                     style: TextStyle(
                                       fontSize: 14,
                                       fontWeight: FontWeight.w600,
                                       color: Colors.orange,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             ...incomingRefs.map((relation) => _buildReferenceItem(relation, notes, isDarkMode, false)),
                           ],
                         ],
                       ),
                     ),
               ),
               
               // 底部按钮
               Padding(
                 padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                 child: SizedBox(
                   width: double.infinity,
                   child: TextButton(
                     onPressed: () => Navigator.pop(context),
                     style: TextButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       backgroundColor: isDarkMode 
                         ? AppTheme.primaryColor.withOpacity(0.1)
                         : AppTheme.primaryColor.withOpacity(0.05),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(10),
                       ),
                     ),
                     child: Text(
                       '关闭',
                       style: TextStyle(
                         color: AppTheme.primaryColor,
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ),
                 ),
               ),
             ],
           ),
         ),
       ),
     );
   }

   // 构建单个引用项目
   Widget _buildReferenceItem(Map<String, dynamic> relation, List<Note> notes, bool isDarkMode, bool isOutgoing) {
     final relatedMemoId = relation['relatedMemoId']?.toString() ?? '';
     final memoId = relation['memoId']?.toString() ?? '';
     final currentId = widget.id.toString();
     
     if (kDebugMode) {
       print('_buildReferenceItem: relation = $relation');
       print('_buildReferenceItem: relatedMemoId = $relatedMemoId, memoId = $memoId, currentId = $currentId');
     }
     
     // 根据引用方向确定要显示的笔记ID
     String targetNoteId;
     if (isOutgoing) {
       // 显示被引用的笔记
       targetNoteId = relatedMemoId;
     } else {
       // 显示引用该笔记的笔记
       targetNoteId = memoId;
     }
     
     // 添加调试信息
     if (kDebugMode) {
       print('ViewReferences: 查找笔记 ID: $targetNoteId');
       print('ViewReferences: 可用笔记: ${notes.map((n) => n.id.toString()).toList()}');
     }
     
     // 查找关联的笔记
     final relatedNote = notes.firstWhere(
       (note) => note.id.toString() == targetNoteId.toString(),
       orElse: () {
         if (kDebugMode) {
           print('ViewReferences: 未找到笔记 ID: $targetNoteId');
         }
         return Note(
           id: targetNoteId,
           content: '笔记不存在 (ID: $targetNoteId)',
           createdAt: DateTime.now(),
           updatedAt: DateTime.now(),
         );
       },
     );
     
     final preview = relatedNote.content.length > 40 
       ? '${relatedNote.content.substring(0, 40)}...'
       : relatedNote.content;
     
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       child: Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: isDarkMode 
             ? Colors.white.withOpacity(0.05)
             : Colors.grey.shade50,
           borderRadius: BorderRadius.circular(12),
           border: Border.all(
             color: (isOutgoing ? Colors.blue : Colors.orange).withOpacity(0.1),
             width: 1,
           ),
         ),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: (isOutgoing ? Colors.blue : Colors.orange).withOpacity(0.1),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Icon(
                 Icons.note_outlined,
                 color: isOutgoing ? Colors.blue : Colors.orange,
                 size: 16,
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     preview,
                     style: TextStyle(
                       fontSize: 14,
                       fontWeight: FontWeight.w500,
                       color: isDarkMode 
                         ? AppTheme.darkTextPrimaryColor 
                         : AppTheme.textPrimaryColor,
                     ),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 4),
                   Text(
                     DateFormat('yyyy-MM-dd HH:mm').format(relatedNote.createdAt),
                     style: TextStyle(
                       fontSize: 11,
                       color: (isDarkMode 
                         ? AppTheme.darkTextSecondaryColor 
                         : AppTheme.textSecondaryColor).withOpacity(0.8),
                     ),
                   ),
                 ],
               ),
             ),
             Icon(
               isOutgoing ? Icons.north_east : Icons.north_west,
               size: 16,
               color: isOutgoing ? Colors.blue : Colors.orange,
             ),
           ],
         ),
       ),
     );
   }
   
     // 添加引用关系（支持离线）
  Future<void> _addReference(String relatedMemoId) async {
     try {
       final appProvider = Provider.of<AppProvider>(context, listen: false);
       final localRefService = LocalReferenceService.instance;
       
       // 创建本地引用关系
       final success = await localRefService.createReference(
         widget.id,
         relatedMemoId,
       );
       
       if (success) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Row(
                 children: [
                   Icon(Icons.check_circle, color: Colors.white, size: 20),
                   SizedBox(width: 8),
                   Text('引用关系已创建'),
                 ],
               ),
               backgroundColor: Colors.green,
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(10),
               ),
             ),
           );
         }
         
         // 如果是在线模式，尝试后台同步到服务器
         if (appProvider.isLoggedIn && !appProvider.isLocalMode) {
           _syncReferenceToServer(widget.id, relatedMemoId);
         }
       } else {
         _showErrorSnackBar('引用失败', '创建引用关系失败', Icons.error_outline);
       }
     } catch (e) {
       if (kDebugMode) print('Error adding reference: $e');
       _showErrorSnackBar('引用失败', '创建引用关系时发生错误', Icons.error_outline);
     }
   }
   
   // 同步引用关系到服务器（后台执行，不阻塞UI）
   Future<void> _syncReferenceToServer(String fromNoteId, String toNoteId) async {
     try {
       final appProvider = Provider.of<AppProvider>(context, listen: false);
       if (!appProvider.isLoggedIn || appProvider.memosApiService == null) return;
       
       if (kDebugMode) {
         // 后台同步引用关系到服务器
       }
       
       // 这里可以调用AppProvider的引用关系同步方法
       // 或者直接使用已有的同步机制
       
     } catch (e) {
       if (kDebugMode) {
         // 后台同步引用关系失败
       }
       // 不显示错误信息，因为本地引用关系已经创建成功
     }
   }
   
   // 显示美化的错误通知
   void _showErrorSnackBar(String title, String message, IconData icon) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Container(
           padding: const EdgeInsets.symmetric(vertical: 4),
           child: Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Icon(
                   icon,
                   color: Colors.white,
                   size: 20,
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(
                       title,
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.w600,
                         fontSize: 14,
                       ),
                     ),
                     const SizedBox(height: 2),
                     Text(
                       message,
                       style: const TextStyle(
                         color: Colors.white,
                         fontSize: 13,
                         height: 1.3,
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         ),
         backgroundColor: Colors.red.shade600,
         behavior: SnackBarBehavior.floating,
         duration: const Duration(seconds: 5),
         margin: const EdgeInsets.all(16),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
         ),
         elevation: 6,
         action: SnackBarAction(
           label: '关闭',
           textColor: Colors.white,
           onPressed: () {
             ScaffoldMessenger.of(context).hideCurrentSnackBar();
           },
         ),
       ),
     );
   }
   
   // 将笔记设置为公开，返回UID
   Future<String?> _setMemoPublic() async {
     try {
       final appProvider = Provider.of<AppProvider>(context, listen: false);
       final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
       final token = appProvider.user?.token;
       
             if (baseUrl.isEmpty || token == null) {
        return null;
      }
       
             final url = '$baseUrl/api/v1/memo/${widget.id}';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      final body = {
        'visibility': 'PUBLIC',  // v1 API使用字符串格式
      };
      
      if (kDebugMode) {
        print('Setting memo public (v1) - URL: $url');
        print('Setting memo public (v1) - Body: ${jsonEncode(body)}');
      }
       
       final response = await http.patch(
         Uri.parse(url),
         headers: headers,
         body: jsonEncode(body),
       );
       
      if (kDebugMode) {
        print('Setting memo public - Response status: ${response.statusCode}');
        print('Setting memo public - Response body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        // 解析v1 API响应，获取UID
        final responseData = jsonDecode(response.body);
        // v1 API响应格式可能不同，先尝试直接获取uid
        final uid = responseData['uid'] ?? responseData['name']?.toString().replaceAll('memos/', '');
        if (kDebugMode) print('Extracted UID (v1): $uid');
        return uid;
      } else {
        return null;
      }
     } catch (e) {
       if (kDebugMode) print('Error setting memo public: $e');
      return null;
     }
   }
   
     // 显示分享链接对话框
  void _showShareLinkDialog(String shareUrl) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentNote = _getCurrentNote();
    final wasAlreadyPublic = currentNote.isPublic;
     
     showDialog(
       context: context,
       builder: (context) => Dialog(
         insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
         backgroundColor: Colors.transparent,
         child: Container(
           decoration: BoxDecoration(
             color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
             borderRadius: BorderRadius.circular(20),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.1),
                 blurRadius: 20,
                 offset: const Offset(0, 10),
               ),
             ],
           ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
               // 优雅的标题区域
             Container(
                 width: double.infinity,
                 padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                 child: Column(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                         color: AppTheme.primaryColor.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(50),
                       ),
                       child: Icon(
                         Icons.link,
                         color: AppTheme.primaryColor,
                         size: 24,
                 ),
               ),
                     const SizedBox(height: 12),
                     Text(
                   "分享链接",
                   style: TextStyle(
                         fontSize: 20,
                     fontWeight: FontWeight.w600,
                         color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                   ),
                 ),
                     const SizedBox(height: 8),
                                            Text(
                         wasAlreadyPublic 
                          ? '您的笔记为公开状态，任何人都可以通过链接访问'
                          : '您的笔记已设置为公开，任何人都可以通过链接访问',
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 14,
                           color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.7),
                   ),
                       ),
                   ],
                 ),
               ),
               
               // 链接展示区域
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 24),
                 child: Container(
                     width: double.infinity,
                   padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                     color: isDarkMode 
                       ? AppTheme.darkSurfaceColor 
                       : AppTheme.primaryColor.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(12),
                       border: Border.all(
                       color: AppTheme.primaryColor.withOpacity(0.2),
                       ),
                     ),
                   child: Row(
                     children: [
                       Icon(
                         Icons.public,
                         color: AppTheme.primaryColor,
                         size: 18,
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child:                            SelectableText(
                       shareUrl,
                             style: TextStyle(
                               fontSize: 13,
                         fontFamily: 'monospace',
                               color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                       ),
                     ],
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 20),
                   
               // 操作按钮区域
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 24),
                 child: Row(
                     children: [
                       Expanded(
                       child: OutlinedButton.icon(
                           onPressed: () async {
                             await Clipboard.setData(ClipboardData(text: shareUrl));
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: const Row(
                                   children: [
                                     Icon(Icons.check_circle, color: Colors.white, size: 20),
                                     SizedBox(width: 8),
                                     Text('链接已复制到剪贴板'),
                                   ],
                                 ),
                                 backgroundColor: Colors.green,
                                 behavior: SnackBarBehavior.floating,
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                               ),
                             );
                           }
                           },
                         icon: const Icon(Icons.copy, size: 18),
                         label: const Text('复制链接'),
                         style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(10),
                           ),
                         ),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: ElevatedButton.icon(
                           onPressed: () {
                             Navigator.pop(context);
                             Share.share(
                             '📝 InkRoot 笔记分享\n\n${widget.content.length > 100 ? '${widget.content.substring(0, 100)}...' : widget.content}\n\n查看完整内容：$shareUrl',
                             subject: '来自 InkRoot 的笔记分享',
                             );
                           },
                         icon: const Icon(Icons.ios_share, size: 18),
                           label: const Text('分享'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: AppTheme.primaryColor,
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(10),
                           ),
                         ),
                         ),
                       ),
                     ],
                 ),
                   ),
                   
               const SizedBox(height: 16),
                   
               // 安全提示
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 24),
                 child: Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                     color: Colors.amber.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(10),
                     border: Border.all(
                       color: Colors.amber.withOpacity(0.3),
                     ),
                     ),
                     child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Icon(
                         Icons.security,
                         color: Colors.amber.shade700,
                         size: 16,
                         ),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                           '此链接为公开链接，任何获得链接的人都可以访问此笔记',
                             style: TextStyle(
                             fontSize: 11,
                             color: Colors.amber.shade800,
                             height: 1.3,
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
               ),
               
               // 关闭按钮
               Padding(
                 padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                 child: SizedBox(
                   width: double.infinity,
                   child: TextButton(
                     onPressed: () => Navigator.pop(context),
                     style: TextButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 12),
                     ),
                     child:                        Text(
                         '关闭',
                         style: TextStyle(
                           color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.7),
                         ),
                       ),
                   ),
               ),
             ),
           ],
           ),
         ),
       ),
     );
   }

     // 分享图片 - 支持所有笔记类型
   void _shareImage() async {
     // 直接显示模板选择界面，不检查图片
     _showImageShareTemplates();
   }

   // 显示图片分享模板选择 - 重新设计为实时预览界面
   void _showImageShareTemplates() {
     Navigator.of(context).push(
       MaterialPageRoute(
         builder: (context) => ShareImagePreviewScreen(
           noteId: widget.id,
           content: widget.content,
           timestamp: widget.timestamp,
         ),
         fullscreenDialog: true,
       ),
     );
   }

   // 显示模板预览界面（图二）
   void _showTemplatePreview() {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

     showDialog(
       context: context,
       builder: (context) => Dialog(
         insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
         backgroundColor: backgroundColor,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             // 标题栏
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
               child: Row(
                 children: [
                   const Expanded(
                     child: Text(
                       "生成分享图",
                       style: TextStyle(
                         fontSize: 20,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                   GestureDetector(
                     onTap: () => Navigator.pop(context),
                     child: Icon(
                       Icons.close,
                       color: Colors.grey[600],
                       size: 24,
                     ),
                   ),
                 ],
               ),
             ),
             
             // 模板预览网格
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: GridView.count(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 crossAxisCount: 2,
                 crossAxisSpacing: 12,
                 mainAxisSpacing: 12,
                 childAspectRatio: 0.8,
                 children: [
                   _buildTemplatePreviewCard("简约模板", ShareTemplate.simple),
                   _buildTemplatePreviewCard("卡片模板", ShareTemplate.card),
                   _buildTemplatePreviewCard("渐变模板", ShareTemplate.gradient),
                   _buildTemplatePreviewCard("日记模板", ShareTemplate.diary),
                 ],
               ),
             ),
             
             // 确定按钮
             Padding(
               padding: const EdgeInsets.all(24),
               child: Container(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: () => Navigator.pop(context),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppTheme.primaryColor,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(12),
                     ),
                   ),
                   child: const Text(
                     "确定",
                     style: TextStyle(
                       fontSize: 16,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                 ),
               ),
             ),
           ],
         ),
       ),
     );
   }

   // 构建模板预览卡片
   Widget _buildTemplatePreviewCard(String title, ShareTemplate template) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     final cardColor = isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
     
     return Container(
       decoration: BoxDecoration(
         color: cardColor,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: AppTheme.primaryColor.withOpacity(0.2),
           width: 1,
         ),
       ),
       child: Column(
         children: [
           // 模板预览图
           Expanded(
             flex: 3,
             child: Container(
               margin: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: _getTemplatePreviewColor(template),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Center(
                 child: _getTemplatePreviewContent(template),
               ),
             ),
           ),
           
           // 模板名称和按钮
           Expanded(
             flex: 2,
             child: Padding(
               padding: const EdgeInsets.all(8),
               child: Column(
                 children: [
                   Text(
                     title,
                     style: const TextStyle(
                       fontSize: 14,
                       fontWeight: FontWeight.w600,
                     ),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(
                         child: TextButton(
                           onPressed: () {
                             Navigator.pop(context);
                             _saveTemplateImage(template);
                           },
                           style: TextButton.styleFrom(
                             padding: const EdgeInsets.symmetric(vertical: 8),
                           ),
                           child: const Text(
                             "保存",
                             style: TextStyle(fontSize: 12),
                           ),
                         ),
                       ),
                       const SizedBox(width: 4),
                       Expanded(
                         child: ElevatedButton(
                           onPressed: () {
                             Navigator.pop(context);
                             _generateShareImage(template);
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: AppTheme.primaryColor,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 8),
                           ),
                           child: const Text(
                             "分享",
                             style: TextStyle(fontSize: 12),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             ),
           ),
         ],
       ),
     );
   }

   // 获取模板预览颜色
   Color _getTemplatePreviewColor(ShareTemplate template) {
     switch (template) {
       case ShareTemplate.simple:
         return Colors.white;
       case ShareTemplate.card:
         return Colors.blue.shade50;
       case ShareTemplate.gradient:
         return Colors.purple.shade100;
       case ShareTemplate.diary:
         return Colors.amber.shade50;
     }
   }

   // 获取模板预览内容
   Widget _getTemplatePreviewContent(ShareTemplate template) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     
     switch (template) {
       case ShareTemplate.simple:
         return Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Container(
               width: 40,
               height: 8,
               decoration: BoxDecoration(
                 color: Colors.grey.shade400,
                 borderRadius: BorderRadius.circular(4),
               ),
             ),
             const SizedBox(height: 4),
             Container(
               width: 60,
               height: 6,
               decoration: BoxDecoration(
                 color: Colors.grey.shade300,
                 borderRadius: BorderRadius.circular(3),
               ),
             ),
           ],
         );
       case ShareTemplate.card:
         return Container(
           margin: const EdgeInsets.all(4),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(6),
             boxShadow: [
               BoxShadow(
                 color: Colors.blue.withOpacity(0.2),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               ),
             ],
           ),
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Container(
                   width: 30,
                   height: 6,
                   decoration: BoxDecoration(
                     color: Colors.blue.shade300,
                     borderRadius: BorderRadius.circular(3),
                   ),
                 ),
                 const SizedBox(height: 3),
                 Container(
                   width: 45,
                   height: 4,
                   decoration: BoxDecoration(
                     color: Colors.grey.shade300,
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
               ],
             ),
           ),
         );
       case ShareTemplate.gradient:
         return Container(
           decoration: BoxDecoration(
             gradient: LinearGradient(
               colors: [Colors.purple.shade200, Colors.pink.shade200],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             ),
             borderRadius: BorderRadius.circular(6),
           ),
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Container(
                   width: 35,
                   height: 6,
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.8),
                     borderRadius: BorderRadius.circular(3),
                   ),
                 ),
                 const SizedBox(height: 3),
                 Container(
                   width: 50,
                   height: 4,
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.6),
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
               ],
             ),
           ),
         );
       case ShareTemplate.diary:
         return Container(
           decoration: BoxDecoration(
             color: Colors.amber.shade100,
             borderRadius: BorderRadius.circular(6),
           ),
           child: Stack(
             children: [
               Positioned(
                 left: 8,
                 top: 0,
                 bottom: 0,
                 child: Container(
                   width: 1,
                   color: Colors.red.shade300,
                 ),
               ),
               Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Container(
                       width: 30,
                       height: 5,
                       decoration: BoxDecoration(
                         color: Colors.brown.shade400,
                         borderRadius: BorderRadius.circular(2),
                       ),
                     ),
                     const SizedBox(height: 3),
                     Container(
                       width: 40,
                       height: 3,
                       decoration: BoxDecoration(
                         color: Colors.brown.shade300,
                         borderRadius: BorderRadius.circular(1),
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         );
     }
   }

   // 保存模板图片
   void _saveTemplateImage(ShareTemplate template) async {
     try {
       // 获取笔记的图片路径
       final List<String> imagePaths = [];
       
       // 从现有笔记获取图片资源
       final provider = Provider.of<AppProvider>(context, listen: false);
       final notes = provider.notes;
       final currentNote = notes.firstWhere(
         (note) => note.id == widget.id,
         orElse: () => Note(
           id: widget.id,
           content: widget.content,
           createdAt: widget.timestamp,
           updatedAt: widget.timestamp,
         ),
       );
       
       for (var resource in currentNote.resourceList) {
         final uid = resource['uid'] as String?;
         if (uid != null) {
           final resourcePath = '/o/r/$uid';
           imagePaths.add(resourcePath);
         }
       }
       
       // 从content中提取Markdown格式的图片
       final RegExp imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
       final imageMatches = imageRegex.allMatches(widget.content);
       
       for (var match in imageMatches) {
         final path = match.group(1) ?? '';
         if (path.isNotEmpty && !imagePaths.contains(path)) {
           imagePaths.add(path);
         }
       }
       
       final success = await ShareUtils.saveImageToGallery(
         context: context,
         content: widget.content,
         timestamp: widget.timestamp,
         template: template,
         imagePaths: imagePaths,
       );
       
             if (success) {
        SnackBarUtils.showSuccess(context, '图片保存成功！');
      } else {
        SnackBarUtils.showError(context, '图片保存失败，请稍后再试');
      }
    } catch (e) {
      SnackBarUtils.showError(context, '保存失败: ${e.toString()}');
     }
   }

   // 构建简洁模板选项
   Widget _buildSimpleTemplateOption(String title, VoidCallback onTap) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     final textColor = isDarkMode ? Colors.white : Colors.black87;
     
     return GestureDetector(
       onTap: onTap,
       child: Container(
         width: double.infinity,
         padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
         decoration: BoxDecoration(
           color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50,
           borderRadius: BorderRadius.circular(12),
           border: Border.all(
             color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
             width: 1,
           ),
         ),
         child: Text(
           title,
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.w500,
             color: textColor,
           ),
           textAlign: TextAlign.center,
         ),
       ),
     );
   }

   // 构建模板选项
   Widget _buildTemplateOption(
     BuildContext context,
     String title,
     String description,
     IconData icon,
     VoidCallback onTap,
   ) {
     final isDarkMode = Theme.of(context).brightness == Brightness.dark;
     final cardColor = isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
     
     return Container(
       decoration: BoxDecoration(
         color: cardColor,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: AppTheme.primaryColor.withOpacity(0.2),
           width: 1,
         ),
       ),
       padding: const EdgeInsets.all(12),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(
             icon,
             size: 32,
             color: AppTheme.primaryColor,
           ),
           const SizedBox(height: 8),
           Text(
             title,
             style: const TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.w600,
             ),
             textAlign: TextAlign.center,
           ),
           const SizedBox(height: 4),
           Text(
             description,
             style: TextStyle(
               fontSize: 11,
               color: isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600],
             ),
             textAlign: TextAlign.center,
             maxLines: 2,
             overflow: TextOverflow.ellipsis,
           ),
           const SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: GestureDetector(
                   onTap: () {
                     Navigator.pop(context);
                     // 根据title转换为ShareTemplate枚举
                     ShareTemplate template;
                     switch (title) {
                       case "简约模板":
                         template = ShareTemplate.simple;
                         break;
                       case "卡片模板":
                         template = ShareTemplate.card;
                         break;
                       case "渐变模板":
                         template = ShareTemplate.gradient;
                         break;
                       case "日记模板":
                         template = ShareTemplate.diary;
                         break;
                       default:
                         template = ShareTemplate.simple;
                     }
                     _saveTemplateImage(template);
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(vertical: 4),
                     decoration: BoxDecoration(
                       color: AppTheme.accentColor.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Text(
                       '保存',
                       style: TextStyle(
                         fontSize: 10,
                         color: AppTheme.accentColor,
                         fontWeight: FontWeight.w500,
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ),
               ),
               const SizedBox(width: 4),
               Expanded(
                 child: GestureDetector(
                   onTap: () {
                     Navigator.pop(context);
                     onTap();
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(vertical: 4),
                     decoration: BoxDecoration(
                       color: AppTheme.primaryColor.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Text(
                       '分享',
                       style: TextStyle(
                         fontSize: 10,
                         color: AppTheme.primaryColor,
                         fontWeight: FontWeight.w500,
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ),
               ),
             ],
           ),
         ],
       ),
     );
   }

   // 分享原有图片
   void _shareExistingImages(List<String> imagePaths) async {
     try {
       final List<XFile> files = [];
       
       for (String imagePath in imagePaths) {
         try {
           final imageBytes = await _getImageBytes(imagePath);
           final fileName = 'note_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
           
           // 创建临时文件
           final tempDir = await getTemporaryDirectory();
           final file = File('${tempDir.path}/$fileName');
           await file.writeAsBytes(imageBytes);
           
           files.add(XFile(file.path));
         } catch (e) {
           if (kDebugMode) print('Error processing image $imagePath: $e');
         }
       }
       
       if (files.isNotEmpty) {
         await Share.shareXFiles(
           files,
           text: '📝 来自墨鸣笔记的分享\n\n${widget.content}',
         );
         
                 SnackBarUtils.showSuccess(context, '图片分享成功！');
      } else {
        SnackBarUtils.showError(context, '无法加载图片，请稍后再试');
      }
    } catch (e) {
      if (kDebugMode) print('Error sharing images: $e');
      SnackBarUtils.showError(context, '分享失败，请稍后再试');
     }
   }

  // 生成分享图片（优化版 - 带进度显示）
  void _generateShareImage(ShareTemplate template) async {
    // 进度状态管理
    double progress = 0.0;
    String progressText = '准备生成图片...';
    
    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkCardColor 
                : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  progressText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '生成高质量分享图片需要一些时间',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[400] 
                      : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // 获取笔记的图片路径
      final List<String> imagePaths = [];
      
      // 从现有笔记获取图片资源
      final provider = Provider.of<AppProvider>(context, listen: false);
      final notes = provider.notes;
      final currentNote = notes.firstWhere(
        (note) => note.id == widget.id,
        orElse: () => Note(
          id: widget.id,
          content: widget.content,
          createdAt: widget.timestamp,
          updatedAt: widget.timestamp,
        ),
      );
      
      for (var resource in currentNote.resourceList) {
        final uid = resource['uid'] as String?;
        if (uid != null) {
          final resourcePath = '/o/r/$uid';
          imagePaths.add(resourcePath);
        }
      }
      
      // 从content中提取Markdown格式的图片
      final RegExp imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
      final imageMatches = imageRegex.allMatches(widget.content);
      
      for (var match in imageMatches) {
        final path = match.group(1) ?? '';
        if (path.isNotEmpty && !imagePaths.contains(path)) {
          imagePaths.add(path);
        }
      }
      
      final success = await ShareUtils.generateShareImageWithProgress(
        context: context,
        content: widget.content,
        timestamp: widget.timestamp,
        template: template,
        imagePaths: imagePaths,
        onProgress: (progressValue) {
          // 更新进度对话框
          if (mounted) {
            setState(() {
              progress = progressValue;
              if (progressValue <= 0.1) {
                progressText = '正在分析图片...';
              } else if (progressValue <= 0.4) {
                progressText = '正在加载图片...';
              } else if (progressValue <= 0.8) {
                progressText = '正在生成分享图片...';
              } else {
                progressText = '正在保存图片...';
              }
            });
          }
        },
      );
      
      // 关闭加载对话框
      if (context.mounted) Navigator.of(context).pop();
      
      if (success) {
        _showModernSnackBar(context, '图片生成并分享成功！', Icons.check_circle);
      } else {
        _showModernSnackBar(context, '图片生成失败，请稍后再试', Icons.error_outline);
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) Navigator.of(context).pop();
      _showModernSnackBar(context, '生成图片时发生错误', Icons.error_outline);
      if (kDebugMode) print('Error generating share image: $e');
    }
  }
 
    // 获取图片字节数据
  Future<Uint8List> _getImageBytes(String imagePath) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.resourceService != null) {
      final fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
      final token = appProvider.user?.token;
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(Uri.parse(fullUrl), headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load image bytes for $imagePath');
      }
    } else {
      final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
      if (baseUrl.isNotEmpty) {
        final token = appProvider.user?.token;
        final fullUrl = '$baseUrl$imagePath';
        final headers = <String, String>{};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        final response = await http.get(Uri.parse(fullUrl), headers: headers);
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('Failed to load image bytes for $imagePath');
        }
      }
    }
    throw Exception('Resource service not available for image $imagePath');
  }

  // 显示保存图片对话框
  void _showSaveImageDialog(List<String> imagePaths) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final headerBgColor = isDarkMode 
      ? AppTheme.primaryColor.withOpacity(0.15) 
      : AppTheme.primaryColor.withOpacity(0.05);
    final footerBgColor = isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
    final footerTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey.shade600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80.0),
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Center(
                child: Text(
                  "保存图片",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '您想要将图片保存到相册吗？',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (imagePaths.isNotEmpty)
                    _buildUniformImageGrid(imagePaths),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final List<XFile> files = [];
                            for (String imagePath in imagePaths) {
                              try {
                                final imageBytes = await _getImageBytes(imagePath);
                                final fileName = 'note_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                final tempDir = await getTemporaryDirectory();
                                final file = File('${tempDir.path}/$fileName');
                                await file.writeAsBytes(imageBytes);
                                files.add(XFile(file.path));
                              } catch (e) {
                                if (kDebugMode) print('Error saving image $imagePath: $e');
                              }
                            }
                            if (files.isNotEmpty) {
                              await Share.shareXFiles(
                                files,
                                text: '📝 来自墨鸣笔记的分享\n\n${widget.content}',
                              );
                              SnackBarUtils.showSuccess(context, '图片已保存到相册并分享！');
                            } else {
                              SnackBarUtils.showError(context, '无法保存图片，请稍后再试');
                            }
                          },
                          child: const Text('保存并分享'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: footerBgColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "字数统计: ${widget.content.length}",
                    style: TextStyle(
                      fontSize: 12,
                      color: footerTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.timestamp)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: footerTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "最后编辑: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.timestamp)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: footerTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建引用关系显示
  Widget _buildReferences() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context, listen: true);
    final notes = appProvider.notes;
    
    // 获取当前笔记的信息，包括关系
    final currentNote = notes.firstWhere(
      (note) => note.id == widget.id.toString(),
      orElse: () => Note(
        id: widget.id.toString(),
        content: widget.content,
        createdAt: widget.timestamp,
        updatedAt: widget.timestamp,
      ),
    );
    
    // 如果没有引用关系，返回空Widget
    if (currentNote.relations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 分析引用关系：区分引用和被引用
    final outgoingRefs = <Map<String, dynamic>>[];  // 当前笔记引用的其他笔记（↗）
    final incomingRefs = <Map<String, dynamic>>[];  // 其他笔记引用当前笔记（↖）
    
    final currentId = widget.id.toString();
    
    // 1. 检查当前笔记的引用关系（当前笔记引用的其他笔记）
    for (final relation in currentNote.relations) {
      final type = relation['type'];
      if (type == 1 || type == 'REFERENCE') {
        final memoId = relation['memoId']?.toString();
        final relatedMemoId = relation['relatedMemoId']?.toString();
        
        if (memoId == currentId || memoId == null) {
          // 当前笔记引用了其他笔记（outgoing reference）
          outgoingRefs.add(relation);
        }
      }
    }
    
    // 2. 检查当前笔记的被引用关系（incoming references）
    for (final relation in currentNote.relations) {
      final type = relation['type'];
      if (type == 'REFERENCED_BY') {
        final fromNoteId = relation['memoId']?.toString();
        
        if (fromNoteId != null && fromNoteId != currentId) {
          // 找到引用当前笔记的源笔记
          final allNotes = Provider.of<AppProvider>(context, listen: false).notes;
          final sourceNote = allNotes.firstWhere(
            (note) => note.id == fromNoteId,
            orElse: () => Note(
              id: fromNoteId,
              content: '未找到笔记',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          
          incomingRefs.add({
            ...relation,
            'fromNoteId': fromNoteId,
            'fromNoteContent': sourceNote.content.length > 50 
                ? '${sourceNote.content.substring(0, 50)}...' 
                : sourceNote.content,
          });
        }
      }
    }
    
    if (outgoingRefs.isEmpty && incomingRefs.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 返回简洁的角标样式
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // 引用其他笔记的图标（↗）
          if (outgoingRefs.isNotEmpty)
            GestureDetector(
              onTap: () => _showReferencesDialog(context, outgoingRefs, '引用的笔记'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.north_east,  // 右斜上方箭头
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${outgoingRefs.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // 被其他笔记引用的图标（↖）
          if (incomingRefs.isNotEmpty)
            GestureDetector(
              onTap: () => _showReferencesDialog(context, incomingRefs, '被引用'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.north_west,  // 左斜上方箭头
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${incomingRefs.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
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

  // 显示引用关系详细对话框
  void _showReferencesDialog(BuildContext context, List<Map<String, dynamic>> references, String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final notes = appProvider.notes;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.link,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.contains('引用的笔记') 
                        ? '该笔记引用了 ${references.length} 个其他笔记'
                        : '有 ${references.length} 个笔记引用了该笔记',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 引用列表
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.all(16),
                child: references.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.link_off,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无引用关系',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: references.length,
                      itemBuilder: (context, index) {
                        final relation = references[index];
                        final memoId = relation['memoId']?.toString() ?? '';
                        final relatedMemoId = relation['relatedMemoId']?.toString() ?? '';
                        final currentId = widget.id.toString();
                        
                        // 根据引用方向确定要显示的笔记ID
                        String targetNoteId;
                        if (memoId == currentId) {
                          // 当前笔记引用了其他笔记，显示被引用的笔记
                          targetNoteId = relatedMemoId;
                        } else {
                          // 其他笔记引用了当前笔记，显示引用的笔记
                          targetNoteId = memoId;
                        }
                        
                        // 查找关联的笔记
                        if (kDebugMode) {
                                  // 查找引用的笔记
                        }
                        
                        final relatedNote = notes.firstWhere(
                          (note) => note.id.toString() == targetNoteId.toString(),
                          orElse: () {
                            if (kDebugMode) {
                              // 未找到引用的笔记
                            }
                            return Note(
                              id: targetNoteId,
                              content: '笔记不存在 (ID: $targetNoteId)',
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            );
                          },
                        );
                        
                        final preview = relatedNote.content.length > 50 
                          ? '${relatedNote.content.substring(0, 50)}...'
                          : relatedNote.content;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              // 这里可以添加跳转到被引用笔记的逻辑
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.note_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preview,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode 
                                              ? AppTheme.darkTextPrimaryColor 
                                              : AppTheme.textPrimaryColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.link,
                                              size: 12,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '引用关系',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppTheme.primaryColor.withOpacity(0.7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
              
              // 底部按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: isDarkMode 
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 保存特定模板的图片

  // 获取当前笔记的完整信息
  Note _getCurrentNote() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final notes = appProvider.notes;
    
    return notes.firstWhere(
      (note) => note.id.toString() == widget.id.toString(),
      orElse: () => Note(
        id: widget.id.toString(),
        content: widget.content,
        createdAt: widget.timestamp,
        updatedAt: widget.timestamp,
      ),
    );
  }
  
  // 显示权限确认对话框
  void _showPublicPermissionDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 警告图标区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.public_rounded,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "分享权限确认",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '要分享此笔记，需要将其设置为公开状态。\n任何拥有链接的人都可以查看该笔记的内容。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 风险提示
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '笔记将变为公开状态，无法撤销',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 按钮区域
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.darkSurfaceColor
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () => Navigator.of(context).pop(),
                            child: Center(
                              child: Text(
                                '取消',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode 
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              Navigator.of(context).pop();
                              _proceedWithSharing();
                            },
                            child: const Center(
                              child: Text(
                                '确定并分享',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
  }
  
  // 执行分享操作
  void _proceedWithSharing() async {
    try {
      // 显示加载状态
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在生成分享链接...'),
            ],
          ),
        ),
      );
      
      // 获取分享链接
      final shareUrl = await _getShareUrl();
      
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      if (shareUrl != null) {
        // 显示分享链接对话框
        _showShareLinkDialog(shareUrl);
      } else {
        SnackBarUtils.showError(context, '生成分享链接失败，请稍后再试');
      }
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      if (kDebugMode) print('Error sharing link: $e');
      
      // 根据错误类型显示不同的提示
      String errorTitle;
      String errorMessage;
      IconData errorIcon;
      
      if (e.toString().contains('系统管理员已禁用公开分享功能')) {
        errorTitle = '分享功能已禁用';
        errorMessage = '系统管理员已禁用公开分享功能，请联系管理员启用后重试';
        errorIcon = Icons.admin_panel_settings;
      } else if (e.toString().contains('无法将笔记设置为公开')) {
        errorTitle = '设置失败';
        errorMessage = '无法将笔记设置为公开状态，可能是权限不足或网络问题';
        errorIcon = Icons.lock;
      } else if (e.toString().contains('服务器地址为空')) {
        errorTitle = '配置错误';
        errorMessage = '服务器地址未配置，请检查应用设置';
        errorIcon = Icons.settings;
      } else if (e.toString().contains('请先登录')) {
        errorTitle = '需要登录';
        errorMessage = '请先登录后再使用分享链接功能';
        errorIcon = Icons.login;
      } else {
        errorTitle = '分享失败';
        errorMessage = '生成分享链接时发生未知错误，请稍后重试';
        errorIcon = Icons.error_outline;
      }
      
      _showErrorSnackBar(errorTitle, errorMessage, errorIcon);
    }
  }

  // 直接复制分享链接（用于已经是公开状态的笔记）
  Future<void> _copyShareLinkDirectly() async {
    try {
      final shareUrl = await _getShareUrl();
      if (shareUrl != null) {
        await Clipboard.setData(ClipboardData(text: shareUrl));
        if (context.mounted) {
          _showModernSnackBar(context, '链接已复制', Icons.link);
        }
      } else {
        if (context.mounted) {
          SnackBarUtils.showError(context, '生成分享链接失败，请稍后再试');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error copying share link: $e');
      if (context.mounted) {
        SnackBarUtils.showError(context, '复制链接失败，请稍后再试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final List<BoxShadow>? cardShadow = isDarkMode ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(
        left: 8.0,    // 左边距8px
        right: 8.0,   // 右边距8px
        bottom: 5.0,  // 底部间距5px，这样两个卡片之间的间距就是5px
      ),
      child: Dismissible(
        key: ValueKey(widget.id), // Use id instead of content
        direction: DismissDirection.endToStart,
        background: Container(color: cardColor),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          child: const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            widget.onDelete();
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_scaleAnimation.value * 0.03),
              child:               GestureDetector(
                onTapDown: (_) => _controller.forward(),
                onTapUp: (_) => _controller.reverse(),
                onTapCancel: () => _controller.reverse(),
                onTap: () {
                  // 跳转到笔记详情页
                  context.go('/note/${widget.id}');
                },
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: cardShadow,
                      border: widget.isPinned 
                        ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5)
                      : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 顶部栏：时间和更多按钮
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('yyyy-MM-dd HH:mm').format(widget.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: (isDarkMode 
                                          ? AppTheme.darkBackgroundColor 
                                          : AppTheme.backgroundColor).withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.more_horiz,
                                        color: isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600],
                                        size: 14,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showMoreOptions(context),
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8), // 减小顶部和内容之间的间距
                              _buildContent(),
                              _buildReferences(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 

// 图片查看器页面
class _ImageViewerScreen extends StatelessWidget {
  final String imagePath;
  
  const _ImageViewerScreen({required this.imagePath});
  
  // 静态图片处理方法
  static ImageProvider _getImageProvider(String uriString, BuildContext context) {
    try {
      if (uriString.startsWith('http://') || uriString.startsWith('https://')) {
        // 网络图片
        return NetworkImage(uriString);
      } else if (uriString.startsWith('/o/r/') || uriString.startsWith('/file/') || uriString.startsWith('/resource/')) {
        // Memos服务器资源路径，支持多种路径格式
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.resourceService != null) {
          final fullUrl = appProvider.resourceService!.buildImageUrl(uriString);
          final token = appProvider.user?.token;
          // if (kDebugMode) print('ImageViewer: 加载Memos图片 - 原路径: $uriString, URL: $fullUrl, 有Token: ${token != null}');
          if (token != null) {
            return CachedNetworkImageProvider(
              fullUrl, 
              headers: {'Authorization': 'Bearer $token'}
            );
          } else {
            return CachedNetworkImageProvider(fullUrl);
          }
        } else {
          // 如果没有资源服务，尝试使用基础URL
          final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          if (baseUrl.isNotEmpty) {
            final token = appProvider.user?.token;
            final fullUrl = '$baseUrl$uriString';
            // if (kDebugMode) print('ImageViewer: 加载Memos图片(fallback) - URL: $fullUrl, 有Token: ${token != null}');
            if (token != null) {
              return CachedNetworkImageProvider(
                fullUrl, 
                headers: {'Authorization': 'Bearer $token'}
              );
            } else {
              return CachedNetworkImageProvider(fullUrl);
            }
          }
        }
        return const AssetImage('assets/images/logo.png');
      } else if (uriString.startsWith('file://')) {
        // 本地文件
        String filePath = uriString.replaceFirst('file://', '');
        return FileImage(File(filePath));
      } else if (uriString.startsWith('resource:')) {
        // 资源图片
        String assetPath = uriString.replaceFirst('resource:', '');
        return AssetImage(assetPath);
      } else {
        // 未知路径格式，记录并使用默认图片
        // if (kDebugMode) print('NoteCard: 未知图片路径格式: $uriString');
        return const AssetImage('assets/images/logo.png');
      }
    } catch (e) {
      if (kDebugMode) print('Error in _getImageProvider: $e');
      return const AssetImage('assets/images/logo.png');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          '查看原图', // 🚀 提示用户这是高清原图
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: _buildCachedImage(context),
          ),
        ),
      ),
    );
  }
  
  // 🚀 构建带缓存的图片（微信方案：磁盘+内存双缓存）
  Widget _buildCachedImage(BuildContext context) {
    // 处理网络图片 - 全屏原图（90天缓存）
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('正在加载高清原图...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        errorWidget: (context, url, error) {
          if (kDebugMode) print('Full screen image error: $error');
          // 🔥 离线模式：尝试从缓存加载
          return FutureBuilder<File?>(
            future: ImageCacheManager.authImageCache.getFileFromCache(url).then((info) => info?.file),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.file(snapshot.data!, fit: BoxFit.contain);
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text('无法加载图片', style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('网络连接失败且无缓存', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              );
            },
          );
        },
      );
    }
    
    // 处理 Memos 服务器资源
    if (imagePath.startsWith('/o/r/') || imagePath.startsWith('/file/') || imagePath.startsWith('/resource/')) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.resourceService != null) {
        final fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
        final token = appProvider.user?.token;
        
        Map<String, String> headers = {};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        
        return CachedNetworkImage(
          imageUrl: fullUrl,
          cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
          httpHeaders: headers,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('正在加载高清原图...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          errorWidget: (context, url, error) {
            if (kDebugMode) print('Full screen image error: $error');
            // 🔥 离线模式：尝试从缓存加载
            return FutureBuilder<File?>(
              future: ImageCacheManager.authImageCache.getFileFromCache(fullUrl).then((info) => info?.file),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.contain);
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text('无法加载图片', style: TextStyle(color: Colors.white, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('认证失败且无缓存', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                );
              },
            );
          },
        );
      }
    }
    
    // 处理本地文件
    if (imagePath.startsWith('file://')) {
      String filePath = imagePath.replaceFirst('file://', '');
      return Image.file(
        File(filePath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
              SizedBox(height: 16),
              Text('无法加载图片', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          );
        },
      );
    }
    
    // 未知格式
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
        SizedBox(height: 16),
        Text('不支持的图片格式', style: TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}

// 全部图片页面
class _AllImagesScreen extends StatelessWidget {
  final List<String> imagePaths;
  
  const _AllImagesScreen({required this.imagePaths});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('全部图片 (${imagePaths.length})', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: EdgeInsets.all(4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemCount: imagePaths.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _ImageViewerScreen(imagePath: imagePaths[index]),
                  ),
                );
              },
              child: _buildGridItem(imagePaths[index], context),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildGridItem(String path, BuildContext context) {
    ImageProvider imageProvider = _ImageViewerScreen._getImageProvider(path, context);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: Colors.grey[800],
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
                              if (kDebugMode) print('Grid image error: $error for $path');
            return Container(
              color: Colors.grey[800],
              child: Icon(Icons.broken_image, color: Colors.grey[400]),
            );
          },
        ),
      ),
    );
  }
} 
