import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../models/note_model.dart';
import '../providers/app_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/note_editor.dart';
import '../utils/image_cache_manager.dart'; // 🔥 添加长期缓存

class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final note = appProvider.getNoteById(widget.noteId);
    setState(() {
      _note = note;
    });
  }
  
  // 🔥 处理链接点击
  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;
    
    try {
      // 处理笔记内部引用 [[noteId]]
      if (href.startsWith('[[') && href.endsWith(']]')) {
        final noteId = href.substring(2, href.length - 2);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteDetailScreen(noteId: noteId),
            ),
          );
        }
        return;
      }
      
      // 处理外部链接
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('无法打开链接: $href')),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('链接错误: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
  
  // 🔥 复制笔记内容
  Future<void> _copyNoteContent() async {
    if (_note == null) return;
    
    await Clipboard.setData(ClipboardData(text: _note!.content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('已复制到剪贴板'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showEditNoteForm(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteEditor(
        initialContent: note.content,
        onSave: (content) async {
          if (content.trim().isNotEmpty) {
            try {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              await appProvider.updateNote(note, content);
              await _loadNote(); // 重新加载笔记
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('笔记已更新'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('更新失败: $e'),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  // 构建笔记内容（参考随机回顾样式）
  Widget _buildNoteContent(Note note) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : const Color(0xFF333333);
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : const Color(0xFF666666);
    final codeBgColor = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    final String content = note.content;
    
    // 🔥 从resourceList中提取图片
    List<String> imagePaths = [];
    for (var resource in note.resourceList) {
      final uid = resource['uid'] as String?;
      if (uid != null) {
        imagePaths.add('/o/r/$uid');
      }
    }
    
    // 从content中提取Markdown格式的图片
    final RegExp imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final imageMatches = imageRegex.allMatches(content);
    for (var match in imageMatches) {
      final path = match.group(1) ?? '';
      if (path.isNotEmpty && !imagePaths.contains(path)) {
        imagePaths.add(path);
      }
    }
    
    // 将图片从内容中移除
    String contentWithoutImages = content;
    for (var match in imageMatches) {
      contentWithoutImages = contentWithoutImages.replaceAll(match.group(0) ?? '', '');
    }
    contentWithoutImages = contentWithoutImages.trim();
    
    final RegExp tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    final List<String> parts = contentWithoutImages.split(tagRegex);
    final matches = tagRegex.allMatches(contentWithoutImages);
    
    List<Widget> contentWidgets = [];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        contentWidgets.add(
          MarkdownBody(
            data: parts[i],
            selectable: true,
            onTapLink: (text, href, title) => _handleLinkTap(href),
            imageBuilder: (uri, title, alt) {
              // 🔥 自定义图片构建器，使用90天缓存
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final imagePath = uri.toString();
              
              if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
                return CachedNetworkImage(
                  imageUrl: imagePath,
                  cacheManager: ImageCacheManager.authImageCache, // 90天缓存
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const SizedBox(),
                  ),
                  errorWidget: (context, url, error) {
                    // 🔥 离线模式
                    return FutureBuilder<File?>(
                      future: ImageCacheManager.authImageCache.getFileFromCache(url).then((info) => info?.file),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.file(snapshot.data!, fit: BoxFit.contain);
                        }
                        return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
                      },
                    );
                  },
                );
              } else if (imagePath.startsWith('/o/r/') || imagePath.startsWith('/file/') || imagePath.startsWith('/resource/')) {
                // 🔥 即使退出登录也能加载缓存
                String fullUrl;
                if (appProvider.resourceService != null) {
                  fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
                } else {
                  final serverUrl = appProvider.appConfig.lastServerUrl ?? appProvider.appConfig.memosApiUrl ?? '';
                  fullUrl = serverUrl.isNotEmpty ? '$serverUrl$imagePath' : 'https://memos.didichou.site$imagePath';
                }
                final token = appProvider.user?.token;
                return CachedNetworkImage(
                  imageUrl: fullUrl,
                  cacheManager: ImageCacheManager.authImageCache, // 90天缓存
                  httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const SizedBox(),
                  ),
                  errorWidget: (context, url, error) {
                    // 🔥 离线模式
                    return FutureBuilder<File?>(
                      future: ImageCacheManager.authImageCache.getFileFromCache(fullUrl).then((info) => info?.file),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.file(snapshot.data!, fit: BoxFit.contain);
                        }
                        return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
                      },
                    );
                  },
                );
              } else if (imagePath.startsWith('file://')) {
                return Image.file(
                  File(imagePath.replaceFirst('file://', '')),
                  fit: BoxFit.contain,
                );
              }
              return const SizedBox();
            },
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 14.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: textColor,
              ),
              h1: TextStyle(
                fontSize: 20.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              h2: TextStyle(
                fontSize: 18.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              h3: TextStyle(
                fontSize: 16.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              code: TextStyle(
                fontSize: 14.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: textColor,
                backgroundColor: codeBgColor,
                fontFamily: 'monospace',
              ),
              blockquote: TextStyle(
                fontSize: 14.0,
                height: 1.5,
                letterSpacing: 0.2,
                color: secondaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
      
      // 添加标签
      if (matchIndex < matches.length && i < parts.length - 1) {
        final tag = matches.elementAt(matchIndex).group(1)!;
        contentWidgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#$tag',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
        matchIndex++;
      }
    }

    // 构建最终内容，包括文本和图片
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contentWidgets.isNotEmpty)
          Wrap(
            children: contentWidgets,
            spacing: 2,
            runSpacing: 4,
          ),
        // 🔥 显示图片网格
        if (imagePaths.isNotEmpty) ...[
          if (contentWidgets.isNotEmpty) const SizedBox(height: 12),
          _buildImageGrid(imagePaths),
        ],
      ],
    );
  }
  
  // 🔥 构建图片网格
  Widget _buildImageGrid(List<String> imagePaths) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 4.0;
        final double imageWidth = (constraints.maxWidth - spacing * 2) / 3;
        final int imageCount = imagePaths.length > 9 ? 9 : imagePaths.length;
        
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(imageCount, (index) {
            final imagePath = imagePaths[index];
            return _buildImageItem(imagePath, imageWidth);
          }),
        );
      },
    );
  }
  
  // 🔥 构建单个图片项
  Widget _buildImageItem(String imagePath, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildImageWidget(imagePath),
      ),
    );
  }
  
  // 🔥 构建图片组件
  Widget _buildImageWidget(String imagePath) {
    try {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: imagePath,
          cacheManager: ImageCacheManager.authImageCache,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const SizedBox(),
          ),
          errorWidget: (context, url, error) {
            return FutureBuilder<File?>(
              future: ImageCacheManager.authImageCache.getFileFromCache(url).then((info) => info?.file),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
              },
            );
          },
        );
      } else if (imagePath.startsWith('/o/r/') || imagePath.startsWith('/file/') || imagePath.startsWith('/resource/')) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        String fullUrl;
        if (appProvider.resourceService != null) {
          fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
        } else {
          final serverUrl = appProvider.appConfig.lastServerUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          fullUrl = serverUrl.isNotEmpty ? '$serverUrl$imagePath' : 'https://memos.didichou.site$imagePath';
        }
        final token = appProvider.user?.token;
        return CachedNetworkImage(
          imageUrl: fullUrl,
          cacheManager: ImageCacheManager.authImageCache,
          httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const SizedBox(),
          ),
          errorWidget: (context, url, error) {
            return FutureBuilder<File?>(
              future: ImageCacheManager.authImageCache.getFileFromCache(fullUrl).then((info) => info?.file),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
              },
            );
          },
        );
      } else if (imagePath.startsWith('file://')) {
        return Image.file(
          File(imagePath.replaceFirst('file://', '')),
          fit: BoxFit.cover,
        );
      }
      return const SizedBox();
    } catch (e) {
      print('Error in _buildImageWidget: $e');
      return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
    }
  }

  // 删除笔记
  Future<void> _deleteNote(Note note) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      
      // 先删除本地数据
      await appProvider.deleteNoteLocal(note.id);
      
      // 尝试从服务器删除
      try {
        if (!appProvider.isLocalMode && appProvider.isLoggedIn) {
          await appProvider.deleteNoteFromServer(note.id);
        }
      } catch (e) {
        print('从服务器删除失败，但本地已删除: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('笔记已删除'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(); // 返回主页
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('删除失败: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('笔记详情')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : const Color(0xFF666666);
    final iconColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          '笔记详情',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18.0,
          ),
        ),
        actions: [
          // 🔥 复制按钮
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.copy, size: 20, color: iconColor),
            ),
            tooltip: '复制笔记内容',
            onPressed: _copyNoteContent,
          ),
          // 编辑按钮
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit, size: 20, color: iconColor),
            ),
            tooltip: '编辑笔记',
            onPressed: () => _showEditNoteForm(_note!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          color: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：时间 + 更多按钮
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(_note!.createdAt),
                          style: TextStyle(
                            fontSize: 14.0,
                            color: secondaryTextColor,
                          ),
                        ),
                        if (_note!.reminderTime != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.alarm, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                '提醒: ${DateFormat('MM-dd HH:mm').format(_note!.reminderTime!)}',
                                style: const TextStyle(
                                  fontSize: 12.0,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('操作'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red.shade400),
                                  title: const Text('删除笔记', style: TextStyle(color: Colors.red)),
                                  onTap: () => Navigator.of(context).pop('delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                        
                        if (result == 'delete' && mounted) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange.shade700, size: 28),
                                  const SizedBox(width: 12),
                                  const Text('删除笔记'),
                                ],
                              ),
                              content: const Text('确定要删除这条笔记吗？删除后无法恢复。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            _deleteNote(_note!);
                          }
                        }
                      },
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 中间：笔记内容
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildNoteContent(_note!),
                  ),
                ),
              ),
              
              // 底部：字数统计
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_note!.content.length} 字',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: secondaryTextColor,
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
}
