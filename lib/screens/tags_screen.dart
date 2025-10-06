import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/note_model.dart';
import '../themes/app_theme.dart';
import '../themes/app_typography.dart';
import '../utils/responsive_utils.dart';
import '../widgets/sidebar.dart';
import '../widgets/note_editor.dart';
import '../utils/snackbar_utils.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  String? _selectedTag;
  List<Note> _notesWithTag = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isTagsExpanded = false; // 标签展开状态
  final TextEditingController _searchController = TextEditingController(); // 搜索控制器
  String _searchQuery = ''; // 搜索关键词
  
  @override
  void initState() {
    super.initState();
    // 🚀 初始化（静默）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotes();
      
      // 进入标签页时自动扫描标签，解决首次进入无标签的问题
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.getAllTags().isEmpty) {
        _scanAllNoteTags();
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听AppProvider的变化
    final appProvider = Provider.of<AppProvider>(context);
    // 笔记和标签数据更新
    
    // 每次AppProvider变化时都重新加载标签
    _refreshNotes();
  }

  void _refreshNotes() {
    // 🚀 刷新（静默）
    // 如果有选中的标签，重新过滤
    if (_selectedTag != null) {
      _filterNotesByTag(_selectedTag!);
    }
  }
  
  // 扫描笔记并更新所有标签
  Future<void> _scanAllNoteTags() async {
    // 🚀 扫描标签（静默）
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 显示加载中对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.responsiveSpacing(context, 16),
          ),
        ),
        content: Container(
          padding: ResponsiveUtils.responsivePadding(context, all: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: ResponsiveUtils.responsiveIconSize(context, 24),
                height: ResponsiveUtils.responsiveIconSize(context, 24),
                child: const CircularProgressIndicator(),
              ),
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
              Text(
                '正在扫描所有笔记中的标签...',
                style: AppTypography.getBodyStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
    
    try {
      // 调用AppProvider的方法扫描所有笔记的标签
      await appProvider.refreshAllNoteTagsWithDatabase();
      
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        // 重新加载标签
        _refreshNotes();
        
        // 显示成功提示
        SnackBarUtils.showSuccess(context, '标签扫描完成');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        // 显示错误提示
        SnackBarUtils.showError(context, '标签扫描失败: $e');
      }
    }
  }
  
  void _selectTag(String tag) {
    // 🚀 选择标签（静默）
    setState(() {
      _selectedTag = tag;
    });
    _filterNotesByTag(tag);
  }
  
  void _filterNotesByTag(String tag) {
    // 🚀 过滤笔记（静默处理，避免打印137条日志）
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final allNotes = appProvider.notes;
    
    final filteredNotes = allNotes.where((note) {
      return note.tags.contains(tag);
    }).toList();
    
    if (kDebugMode) {
      print('TagsScreen: 过滤标签"$tag" - ${filteredNotes.length}/${allNotes.length}条');
    }
    setState(() {
      _notesWithTag = filteredNotes;
    });
  }
  
  // 处理标签和Markdown内容
  Widget _buildContent(String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Color(0xFF333333);
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Color(0xFF666666);
    final codeBgColor = isDarkMode ? Color(0xFF2C2C2C) : Color(0xFFF5F5F5);
    
    // 首先处理标签
    final RegExp tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    final List<String> parts = content.split(tagRegex);
    final matches = tagRegex.allMatches(content);
    
    List<Widget> contentWidgets = [];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        // 非标签部分用Markdown渲染
        contentWidgets.add(
          MarkdownBody(
            data: parts[i],
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

    return Wrap(
      children: contentWidgets,
      spacing: 2,
      runSpacing: 4,
    );
  }
  
  // 显示编辑笔记表单
  void _showEditNoteForm(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => NoteEditor(
        initialContent: note.content,
        onSave: (content) async {
          if (content.trim().isNotEmpty) {
            try {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              await appProvider.updateNote(note, content);
              // 🚀 笔记更新成功（静默）
              
              // 确保所有监听者都收到更新通知
              WidgetsBinding.instance.addPostFrameCallback((_) {
                appProvider.notifyListeners();
              });
              
              // 如果当前有选中的标签，重新过滤笔记
              if (_selectedTag != null) {
                _filterNotesByTag(_selectedTag!);
              }
            } catch (e) {
              if (kDebugMode) print('TagsScreen: 更新笔记失败: $e');
              if (mounted) {
                SnackBarUtils.showError(context, '更新失败: $e');
              }
            }
          }
        },
      ),
    ).then((_) {
      // 🚀 表单关闭（静默）
    });
  }
  
  // 显示笔记操作菜单
  void _showNoteOptions(Note note) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final dividerColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.responsiveSpacing(context, 16)),
        ),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Container(
            width: ResponsiveUtils.responsiveSpacing(context, 40),
            height: ResponsiveUtils.responsiveSpacing(context, 4),
            margin: ResponsiveUtils.responsivePadding(
              context,
              top: 8,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 编辑选项
          ListTile(
            leading: Icon(
              Icons.edit,
              color: Colors.blue,
              size: ResponsiveUtils.responsiveIconSize(context, 24),
            ),
            title: Text(
              '编辑笔记',
              style: AppTypography.getBodyStyle(
                context,
                color: textColor,
              ),
            ),
            contentPadding: ResponsiveUtils.responsivePadding(
              context,
              horizontal: 24,
            ),
            onTap: () {
              Navigator.pop(context);
              _showEditNoteForm(note);
            },
          ),
          
          // 查看详情选项
          ListTile(
            leading: Icon(
              Icons.visibility,
              color: Colors.green,
              size: ResponsiveUtils.responsiveIconSize(context, 24),
            ),
            title: Text(
              '查看详情',
              style: AppTypography.getBodyStyle(
                context,
                color: textColor,
              ),
            ),
            contentPadding: ResponsiveUtils.responsivePadding(
              context,
              horizontal: 24,
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/note/${note.id}', extra: note);
            },
          ),
          
          SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // 🚀 构建UI（静默）
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    final tagSelectedBgColor = isDarkMode ? Color(0xFF1E3A5F) : const Color(0xFFEDF3FF);
    final tagSelectedTextColor = isDarkMode ? Color(0xFF82B1FF) : Colors.blue;
    final tagBorderColor = isDarkMode ? Colors.blue.withOpacity(0.3) : Colors.grey.shade300;
    final tagUnselectedBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final tags = appProvider.getAllTags().toList()..sort();
        // 🚀 标签统计（静默）
        
        return ResponsiveLayout(
          mobile: _buildMobileLayout(context, appProvider, backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, tags),
          tablet: _buildTabletLayout(context, appProvider, backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, tags),
          desktop: _buildDesktopLayout(context, appProvider, backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, tags),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppProvider appProvider, Color backgroundColor, Color cardColor, Color textColor, Color? secondaryTextColor, Color iconColor, List<String> tags) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, iconColor),
      drawer: const Sidebar(),
      body: _buildTagsContent(context, cardColor, textColor, secondaryTextColor, iconColor, tags),
    );
  }

  Widget _buildTabletLayout(BuildContext context, AppProvider appProvider, Color backgroundColor, Color cardColor, Color textColor, Color? secondaryTextColor, Color iconColor, List<String> tags) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, iconColor),
      drawer: const Sidebar(),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: _buildTagsContent(context, cardColor, textColor, secondaryTextColor, iconColor, tags),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppProvider appProvider, Color backgroundColor, Color cardColor, Color textColor, Color? secondaryTextColor, Color iconColor, List<String> tags) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(context, backgroundColor, textColor, iconColor),
      drawer: const Sidebar(),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: _buildTagsContent(context, cardColor, textColor, secondaryTextColor, iconColor, tags),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context, Color backgroundColor, Color textColor, Color iconColor) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: ResponsiveUtils.isMobile(context) ? true : true,
      leading: IconButton(
        icon: Container(
          padding: ResponsiveUtils.responsivePadding(context, all: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.responsiveSpacing(context, 8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveUtils.responsiveSpacing(context, 16),
                height: ResponsiveUtils.responsiveSpacing(context, 2),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 4)),
              Container(
                width: ResponsiveUtils.responsiveSpacing(context, 10),
                height: ResponsiveUtils.responsiveSpacing(context, 2),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        '全部标签',
        style: AppTypography.getTitleStyle(
          context,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      actions: [
        // 用刷新图标替换标签图标
        IconButton(
          icon: Container(
            padding: ResponsiveUtils.responsivePadding(context, all: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.responsiveSpacing(context, 8),
              ),
            ),
            child: Icon(
              Icons.refresh,
              size: ResponsiveUtils.responsiveIconSize(context, 20),
              color: iconColor,
            ),
          ),
          tooltip: '扫描所有笔记的标签',
          onPressed: _scanAllNoteTags,
        ),
        SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
      ],
    );
  }

  Widget _buildTagsContent(BuildContext context, Color cardColor, Color textColor, Color? secondaryTextColor, Color iconColor, List<String> tags) {
    // 根据搜索关键词过滤标签
    final filteredTags = _searchQuery.isEmpty
        ? tags
        : tags.where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    // 计算需要显示的标签
    const int maxInitialTags = 15; // 默认最多显示15个标签（约3行）
    final displayTags = _isTagsExpanded || filteredTags.length <= maxInitialTags
        ? filteredTags
        : filteredTags.take(maxInitialTags).toList();
    
    final hasMoreTags = filteredTags.length > maxInitialTags;
    
    return Column(
      children: [
        // 🔥 标签区域（限制最大高度并可滚动）
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5, // 最多占屏幕一半高度
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 搜索框
                if (tags.length > 10)
                  Container(
                    padding: ResponsiveUtils.responsivePadding(context, horizontal: 16, top: 16, bottom: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '搜索标签...',
                        prefixIcon: Icon(Icons.search, color: iconColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: iconColor, width: 2),
                        ),
                        filled: true,
                        fillColor: cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                
                // 🔥 标签列表（优化后）
                Container(
                  padding: ResponsiveUtils.responsivePadding(context, horizontal: 16, top: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 标签网格
                      Wrap(
                        spacing: ResponsiveUtils.responsiveSpacing(context, 8),
                        runSpacing: ResponsiveUtils.responsiveSpacing(context, 8),
                        children: displayTags.map((tag) {
                          final isSelected = tag == _selectedTag;
                          return InkWell(
                            onTap: () {
                              if (isSelected) {
                                setState(() {
                                  _selectedTag = null;
                                  _notesWithTag = [];
                                });
                              } else {
                                _selectTag(tag);
                              }
                            },
                            child: Container(
                              padding: ResponsiveUtils.responsivePadding(
                                context,
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppTheme.primaryColor.withOpacity(0.1)
                                    : cardColor,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.responsiveSpacing(context, 8),
                                ),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: AppTypography.getCaptionStyle(
                                  context,
                                  color: isSelected ? AppTheme.primaryColor : textColor,
                                ).copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // 🔥 展开/收起按钮
                      if (hasMoreTags && _searchQuery.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isTagsExpanded = !_isTagsExpanded;
                                });
                              },
                              icon: Icon(
                                _isTagsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: iconColor,
                              ),
                              label: Text(
                                _isTagsExpanded 
                                    ? '收起标签 (${filteredTags.length})' 
                                    : '展开更多标签 (${filteredTags.length - maxInitialTags}+)',
                                style: TextStyle(
                                  color: iconColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // 🔥 搜索结果提示
                      if (_searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            filteredTags.isEmpty 
                                ? '未找到匹配的标签' 
                                : '找到 ${filteredTags.length} 个标签',
                            style: AppTypography.getCaptionStyle(
                              context,
                              color: secondaryTextColor,
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
        
        // 分割线
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.shade200,
        ),
        
        // 笔记列表
        Expanded(
          child: _selectedTag == null
              ? _buildEmptyState(context, secondaryTextColor, '选择一个标签以查看相关笔记', Icons.local_offer_outlined)
              : _notesWithTag.isEmpty
                  ? _buildEmptyState(context, secondaryTextColor, '没有找到带有 #$_selectedTag 标签的笔记', Icons.note_outlined)
                  : _buildNotesList(context, cardColor, textColor, secondaryTextColor, iconColor),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, Color? secondaryTextColor, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: ResponsiveUtils.responsiveIconSize(context, 80),
            color: Colors.grey.shade300,
          ),
          SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
          Text(
            message,
            style: AppTypography.getBodyStyle(
              context,
              fontSize: 16,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, Color cardColor, Color textColor, Color? secondaryTextColor, Color iconColor) {
    final borderRadius = ResponsiveUtils.responsive<double>(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    );

    return ListView.builder(
      itemCount: _notesWithTag.length,
      padding: ResponsiveUtils.responsivePadding(context, all: 16),
      itemBuilder: (context, index) {
        final note = _notesWithTag[index];
        return Container(
          margin: ResponsiveUtils.responsivePadding(
            context,
            bottom: 12,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            color: cardColor,
            elevation: ResponsiveUtils.responsive<double>(
              context,
              mobile: 1.0,
              tablet: 2.0,
              desktop: 3.0,
            ),
            child: InkWell(
              onTap: () => context.push('/note/${note.id}', extra: note),
              onLongPress: () => _showNoteOptions(note),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: ResponsiveUtils.responsivePadding(context, all: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 时间显示和操作按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${note.createdAt.year}年${note.createdAt.month}月${note.createdAt.day}日 ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                            style: AppTypography.getCaptionStyle(
                              context,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                        // 添加编辑按钮
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: ResponsiveUtils.responsiveIconSize(context, 18),
                            color: iconColor,
                          ),
                          onPressed: () => _showEditNoteForm(note),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 8)),
                    
                    // 笔记内容
                    _buildContent(note.content),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建图片组件，支持不同类型的图片源
  Widget _buildImageWidget(String imagePath) {
    try {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        // 网络图片
        return CachedNetworkImage(
          imageUrl: imagePath,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) {
            if (kDebugMode) print('TagsScreen: 图片加载错误 $url');
            return Center(child: Icon(Icons.broken_image, color: Colors.grey[600]));
          },
        );
      } else if (imagePath.startsWith('/o/r/') || imagePath.startsWith('/file/') || imagePath.startsWith('/resource/')) {
        // Memos服务器资源路径
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.resourceService != null) {
          final fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
          final token = appProvider.user?.token;
          // 🚀 构建图片（静默）
          
          Map<String, String> headers = {};
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
          
          return Container(
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: fullUrl,
              httpHeaders: headers,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) {
                if (kDebugMode) print('TagsScreen: 图片失败 $fullUrl');
                
                // 尝试从本地文件系统加载
                try {
                  // 检查是否是本地文件路径
                  if (imagePath.startsWith('/') || imagePath.contains('file://')) {
                    // 直接使用完整路径
                    String localPath = imagePath.replaceFirst('file://', '');
                    final localFile = File(localPath);
                    if (localFile.existsSync()) {
                      // 🚀 找到本地图片（静默）
                      return Image.file(
                        localFile,
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
                      print('TagsScreen: 本地图片文件不存在: $localPath');
                    }
                  }
                  
                  // 如果是相对路径，尝试在应用目录中查找
                  if (imagePath.contains('/')) {
                    final fileName = imagePath.split('/').last;
                    if (fileName.isNotEmpty && fileName.contains('.')) {
                      // 尝试在应用文档目录中查找图片
                      return FutureBuilder<Directory>(
                        future: getApplicationDocumentsDirectory(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final localFile = File('${snapshot.data!.path}/images/$fileName');
                            if (localFile.existsSync()) {
                              print('TagsScreen: 在应用目录找到图片: ${localFile.path}');
                              return Image.file(
                                localFile,
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
                    }
                  }
                } catch (e) {
                  print('TagsScreen: 尝试本地加载失败: $e');
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
            ),
          );
        } else {
          // 如果没有资源服务，尝试使用基础URL
          final baseUrl = appProvider.user?.serverUrl ?? appProvider.appConfig.memosApiUrl ?? '';
          if (baseUrl.isNotEmpty) {
            final token = appProvider.user?.token;
            final fullUrl = '$baseUrl$imagePath';
            print('TagsScreen: 加载图片(fallback) - URL: $fullUrl, 有Token: ${token != null}');
            Map<String, String> headers = {};
            if (token != null) {
              headers['Authorization'] = 'Bearer $token';
            }
            return CachedNetworkImage(
              imageUrl: fullUrl,
              httpHeaders: headers,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) {
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
      print('TagsScreen Error in _buildImageWidget: $e for $imagePath');
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