import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/note_model.dart';
import '../themes/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/note_editor.dart';
import '../utils/image_cache_manager.dart'; // 🔥 添加长期缓存

class RandomReviewScreen extends StatefulWidget {
  const RandomReviewScreen({super.key});

  @override
  State<RandomReviewScreen> createState() => _RandomReviewScreenState();
}

class _RandomReviewScreenState extends State<RandomReviewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  final Random _random = Random();
  
  List<Note> _reviewNotes = [];
  int _currentIndex = 0;
  
  // 回顾设置
  int _reviewDays = 30; // 默认回顾最近30天的笔记
  int _reviewCount = 10; // 默认回顾10条笔记

  @override
  void initState() {
    super.initState();
    
    // 初始化时获取笔记
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviewNotes();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  // 加载回顾笔记
  void _loadReviewNotes() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final allNotes = appProvider.notes;
    
    if (allNotes.isEmpty) {
      setState(() {
        _reviewNotes = [];
        _currentIndex = 0;
      });
      return;
    }
    
    // 根据时间范围筛选笔记
    final DateTime cutoffDate = DateTime.now().subtract(Duration(days: _reviewDays));
    final filteredNotes = allNotes.where((note) => note.createdAt.isAfter(cutoffDate)).toList();
    
    // 如果筛选后的笔记不足，则使用全部笔记
    List<Note> availableNotes = filteredNotes.isEmpty ? allNotes : filteredNotes;
    
    // 随机选择指定数量的笔记
    List<Note> selectedNotes = [];
    if (availableNotes.length <= _reviewCount) {
      // 如果可用笔记少于请求的数量，全部使用
      selectedNotes = List.from(availableNotes);
    } else {
      // 随机选择笔记
      availableNotes.shuffle(_random);
      selectedNotes = availableNotes.take(_reviewCount).toList();
    }
    
    // 保持当前笔记的位置
    String currentNoteId = _currentIndex < _reviewNotes.length ? _reviewNotes[_currentIndex].id : '';
    int newIndex = selectedNotes.indexWhere((note) => note.id == currentNoteId);
    
    setState(() {
      _reviewNotes = selectedNotes;
      _currentIndex = newIndex != -1 ? newIndex : 0;
    });
  }

  // 显示编辑笔记表单
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
              _loadReviewNotes(); // 重新加载笔记
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('更新失败: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
  
  // 显示设置对话框
  void _showSettingsDialog() {
    int tempDays = _reviewDays;
    int tempCount = _reviewCount;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final accentColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text(
          '回顾设置',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 时间范围设置
            Row(
              children: [
                Text(
                  '回顾时间范围：',
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: dialogBgColor,
                  ),
                  child: DropdownButton<int>(
                  value: tempDays,
                  items: [7, 14, 30, 60, 90, 180, 365, 999999]
                      .map((days) => DropdownMenuItem<int>(
                            value: days,
                              child: Text(
                                days == 999999 ? '全部' : '$days天',
                                style: TextStyle(color: textColor),
                              ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      tempDays = value;
                    }
                  },
                    dropdownColor: dialogBgColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 回顾数量设置
            Row(
              children: [
                Text(
                  '回顾笔记数量：',
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: dialogBgColor,
                  ),
                  child: DropdownButton<int>(
                  value: tempCount,
                  items: [5, 10, 20, 30, 50, 100]
                      .map((count) => DropdownMenuItem<int>(
                            value: count,
                              child: Text(
                                '$count条',
                                style: TextStyle(color: textColor),
                              ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      tempCount = value;
                    }
                  },
                    dropdownColor: dialogBgColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: accentColor),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _reviewDays = tempDays;
                _reviewCount = tempCount;
              });
              Navigator.pop(context);
              _loadReviewNotes(); // 重新加载笔记
            },
            child: Text(
              '确定',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // 处理页面变化
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  // 打开侧边栏
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }
  
  // 🔥 处理链接点击
  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;
    
    try {
      // 处理笔记内部引用 [[noteId]]
      if (href.startsWith('[[') && href.endsWith(']]')) {
        final noteId = href.substring(2, href.length - 2);
        if (mounted) {
          Navigator.of(context).pushNamed('/note/$noteId');
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
  Future<void> _copyNoteContent(Note note) async {
    await Clipboard.setData(ClipboardData(text: note.content));
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
  
  // 处理标签和Markdown内容
  Widget _buildContent(Note note) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Color(0xFF333333);
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Color(0xFF666666);
    final codeBgColor = isDarkMode ? Color(0xFF2C2C2C) : Color(0xFFF5F5F5);
    
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
    
    // 首先处理标签
    final RegExp tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    final List<String> parts = contentWithoutImages.split(tagRegex);
    final matches = tagRegex.allMatches(contentWithoutImages);
    
    List<Widget> contentWidgets = [];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        // 非标签部分用Markdown渲染
        contentWidgets.add(
          MarkdownBody(
            data: parts[i],
            selectable: true,
            onTapLink: (text, href, title) => _handleLinkTap(href),
            imageBuilder: (uri, title, alt) {
              // 处理图片URL
              String imagePath = uri.toString();
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: _buildImageWidget(imagePath),
                ),
              );
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
      
      // 添加标签 - 更新为与主页一致的样式
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
              style: TextStyle(
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
  
  // 显示笔记操作菜单
  void _showNoteOptions(Note note) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final infoBgColor = isDarkMode ? Colors.grey[850] : Colors.grey.shade100;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80.0),
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 复制选项
            _buildMenuOption(
              title: "复制内容",
              onTap: () {
                Navigator.pop(context);
                _copyNoteContent(note);
              },
            ),
            
            // 编辑选项
            _buildMenuOption(
              title: "编辑",
              onTap: () {
                Navigator.pop(context);
                // 显示编辑器
                _showEditNoteForm(note);
              },
            ),
            
            // 删除选项
            _buildMenuOption(
              title: "删除",
              textColor: Colors.red,
              onTap: () async {
                if (kDebugMode) print('RandomReviewScreen: 准备删除笔记 ID: ${note.id}');
                          Navigator.pop(context); // 关闭菜单对话框
                          
                          try {
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  
                            // 先删除本地数据
                            if (kDebugMode) print('RandomReviewScreen: 删除本地笔记');
                            await appProvider.deleteNoteLocal(note.id);
                            
                            // 显示正在删除的提示
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('正在删除笔记...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                            
                            // 尝试从服务器删除
                            try {
                              if (!appProvider.isLocalMode && appProvider.isLoggedIn) {
                                if (kDebugMode) print('RandomReviewScreen: 从服务器删除笔记');
                                await appProvider.deleteNoteFromServer(note.id);
                              }
                            } catch (e) {
                              if (kDebugMode) print('RandomReviewScreen: 从服务器删除失败，但本地已删除: $e');
                            }
                            
                            if (kDebugMode) print('RandomReviewScreen: 笔记删除成功，刷新列表');
                            // 刷新笔记列表
                            _loadReviewNotes();
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('笔记已删除'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            if (kDebugMode) print('RandomReviewScreen: 删除笔记失败: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('删除失败: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
              },
            ),
            
            // 底部信息区域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBgColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "字数统计: ${note.content.length}",
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "最后编辑: ${DateFormat('yyyy-MM-dd HH:mm').format(note.updatedAt)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
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
  
  // 构建菜单选项
  Widget _buildMenuOption({
    required String title, 
    IconData? icon, 
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: textColor ?? defaultTextColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    final dividerColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];
    final bottomInfoBgColor = isDarkMode ? Colors.grey[850] : Colors.grey.shade100;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawer: const Sidebar(), // 添加侧边栏
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 2,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          onPressed: _openDrawer,
        ),
        centerTitle: true,
        title: Text(
          '随机回顾',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18.0,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings,
                size: 20,
                color: iconColor,
              ),
            ),
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          if (appProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_reviewNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note,
                    size: 80,
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '没有可回顾的笔记',
                    style: TextStyle(
                      fontSize: 16,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: _reviewNotes.length,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final note = _reviewNotes[index];
              return Padding(
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
                      // 时间显示
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(note.createdAt),
                              style: TextStyle(
                                fontSize: 14.0,
                                color: secondaryTextColor,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showNoteOptions(note),
                              child: Icon(
                                Icons.more_horiz,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 笔记内容
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildContent(note),
                          ),
                        ),
                      ),
                      
                      // 底部导航 - 只显示笔记计数
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 当前笔记索引/总数
                            Text(
                              '${index + 1}/${_reviewNotes.length}条笔记',
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
              );
            },
          );
        },
      ),
    );
  }

  // 构建图片组件，支持不同类型的图片源
  Widget _buildImageWidget(String imagePath) {
    try {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        // 🚀 网络图片 - 90天缓存
        return CachedNetworkImage(
          imageUrl: imagePath,
          cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const SizedBox(),
          ),
          errorWidget: (context, url, error) {
            // 🔥 离线模式：尝试从缓存加载
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
        // Memos服务器资源路径
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.resourceService != null) {
          final fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
          final token = appProvider.user?.token;
          if (kDebugMode) print('RandomReview: 构建图片 - 原路径: $imagePath, URL: $fullUrl, 有Token: ${token != null}');
          
          Map<String, String> headers = {};
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
          
          // 🚀 使用90天缓存
          return Container(
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: fullUrl,
              cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
              httpHeaders: headers,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const SizedBox(),
              ),
              errorWidget: (context, url, error) {
                if (kDebugMode) print('RandomReview: 图片加载失败 - URL: $fullUrl, 错误: $error');
                // 🔥 离线模式：尝试从缓存加载
                return FutureBuilder<File?>(
                  future: ImageCacheManager.authImageCache.getFileFromCache(fullUrl).then((info) => info?.file),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.file(snapshot.data!, fit: BoxFit.cover);
                    }
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          );
        } else {
          // 如果没有资源服务，尝试使用基础URL（🔥 即使退出登录也能加载缓存）
          final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.lastServerUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          if (baseUrl.isNotEmpty) {
            final token = appProvider.user?.token;
            final fullUrl = '$baseUrl$imagePath';
            if (kDebugMode) print('RandomReview: 加载图片(fallback) - URL: $fullUrl, 有Token: ${token != null}');
            Map<String, String> headers = {};
            if (token != null) {
              headers['Authorization'] = 'Bearer $token';
            }
            return CachedNetworkImage(
              imageUrl: fullUrl,
              cacheManager: ImageCacheManager.authImageCache, // 🔥 90天缓存
              httpHeaders: headers,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) {
                // 🔥 离线模式
                return FutureBuilder<File?>(
                  future: ImageCacheManager.authImageCache.getFileFromCache(fullUrl).then((info) => info?.file),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.file(snapshot.data!, fit: BoxFit.cover);
                    }
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            );
          }
        }
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } else if (imagePath.startsWith('file://')) {
        // 本地文件
        String filePath = imagePath.replaceFirst('file://', '');
        return Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        );
      } else {
        // 其他情况，尝试作为资源或本地文件处理
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('RandomReview Error in _buildImageWidget: $e for $imagePath');
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }
} 