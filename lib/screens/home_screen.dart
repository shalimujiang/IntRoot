import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../models/note_model.dart';
import '../models/sort_order.dart';
import '../themes/app_theme.dart';
import '../widgets/note_editor.dart';
import '../widgets/sidebar.dart';
import '../widgets/note_card.dart';
import '../widgets/progress_overlay.dart';
import '../utils/snackbar_utils.dart';
import '../utils/responsive_utils.dart';
// import '../utils/share_helper.dart'; // 🔥 分享接收助手（暂时禁用）
import '../config/app_config.dart';
import 'dart:ui';
import 'dart:async'; // 🚀 用于搜索防抖

class HomeScreen extends StatefulWidget {
  final String? sharedContent; // 🔥 接收分享的内容
  
  const HomeScreen({super.key, this.sharedContent});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<Note> _searchResults = [];
  bool _isRefreshing = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  SortOrder _currentSortOrder = SortOrder.newest;
  bool _hasAutoMarkedNotificationAsRead = false; // 🎯 跟踪是否已自动标记通知为已读
  
  // 🚀 分页加载相关
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  
  // 🚀 搜索防抖
  Timer? _searchDebounce;
  
  // 🔥 分享接收助手（暂时禁用）
  // final ShareHelper _shareHelper = ShareHelper();
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    
    // 🚀 添加滚动监听，实现分页加载
    _scrollController.addListener(_onScroll);
    
    // 在页面加载完成后异步检查更新和通知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _refreshNotifications();
      
      // 🔥 如果有分享的内容，打开编辑器（延迟确保页面完全加载）
      if (widget.sharedContent != null && widget.sharedContent!.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showAddNoteFormWithContent(widget.sharedContent!);
          }
        });
      }
    });
  }
  
  // 🚀 滚动监听 - 检测底部并加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      // 距离底部300px时开始加载
      _loadMoreNotes();
    }
  }
  
  // 🚀 加载更多笔记
  Future<void> _loadMoreNotes() async {
    if (_isLoadingMore) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (!appProvider.hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      await appProvider.loadMoreNotes();
    } catch (e) {
      if (kDebugMode) print('HomeScreen: 加载更多失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  
  // 🔥 检查并处理待分享的内容（暂时禁用）
  /*
  void _checkPendingShared() {
    if (_shareHelper.hasPendingShared()) {
      if (kDebugMode) print('HomeScreen: 检测到待处理的分享内容');
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      _shareHelper.checkAndHandleShared(
        context,
        (content) async {
          try {
            if (kDebugMode) print('HomeScreen: 从分享创建笔记，内容长度: ${content.length}');
            await appProvider.createNote(content);
            if (kDebugMode) print('HomeScreen: 分享笔记创建成功');
          } catch (e) {
            if (kDebugMode) print('HomeScreen: 创建分享笔记失败: $e');
            if (mounted) {
              SnackBarUtils.showError(context, '创建笔记失败: $e');
            }
          }
        },
      );
    }
  }
  */
  
  // 异步检查更新
  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // 异步检查更新，不阻塞UI
    appProvider.checkForUpdatesOnStartup().then((_) {
      if (mounted) {
        appProvider.showUpdateDialogIfNeeded(context);
      }
    });
  }
  
  // 刷新通知数据
  Future<void> _refreshNotifications() async {
    if (!mounted) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // 异步刷新通知数量，不阻塞UI
    appProvider.refreshUnreadAnnouncementsCount();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    _scrollController.dispose(); // 🚀 释放滚动控制器
    _searchDebounce?.cancel(); // 🚀 取消防抖定时器
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    if (!mounted) return;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (!appProvider.isInitialized) {
      await appProvider.initializeApp();
    }
    
    // 后台数据同步现在已经在AppProvider.initializeApp中自动处理
    // 无需在UI层再次触发
  }
  
  // 刷新笔记数据
  Future<void> _refreshNotes() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      
      // 🚀 使用增量同步：速度快10倍以上！
      if (appProvider.isLoggedIn && !appProvider.isLocalMode) {
        if (kDebugMode) {
          // 🚀 执行增量同步（静默）
        }
        await appProvider.refreshFromServerFast();
        
        // 显示同步成功提示
        if (mounted) {
          SnackBarUtils.showSuccess(context, '同步成功');
        }
      } else {
        // 本地模式下重新加载本地数据
        if (kDebugMode) {
          // 🚀 加载本地数据（静默）
        }
        await appProvider.loadNotesFromLocal();
        
        // 显示刷新成功提示
        if (mounted) {
          SnackBarUtils.showSuccess(context, '刷新成功');
        }
      }
      
    } catch (e) {
      if (kDebugMode) print('HomeScreen: 刷新失败: $e');
      // 显示刷新失败提示
      if (mounted) {
        SnackBarUtils.showError(context, '刷新失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // 显示排序选项（iOS风格）
  void _showSortOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final primaryColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;

    showModalBottomSheet(
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
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '排序方式',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 排序选项
              _buildSortOption('最新优先', SortOrder.newest, primaryColor, textColor),
              _buildSortOption('最旧优先', SortOrder.oldest, primaryColor, textColor),
              _buildSortOption('更新时间', SortOrder.updated, primaryColor, textColor),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 构建排序选项
  Widget _buildSortOption(String title, SortOrder sortOrder, Color primaryColor, Color textColor) {
    final isSelected = _currentSortOrder == sortOrder;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? primaryColor : textColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected 
        ? Icon(
            Icons.check,
            color: primaryColor,
            size: 20,
          )
        : null,
      onTap: () {
        setState(() {
          _currentSortOrder = sortOrder;
        });
        Navigator.pop(context);
        _applySorting();
      },
    );
  }

  // 应用排序
  void _applySorting() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.setSortOrder(_currentSortOrder);
  }
  
  // 显示添加笔记表单
  void _showAddNoteForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => NoteEditor(
        onSave: (content) async {
          if (content.trim().isNotEmpty) {
            try {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final note = await appProvider.createNote(content);
              // 🚀 笔记创建成功（静默）
              
              // 如果用户已登录但笔记未同步，尝试再次同步
              if (appProvider.isLoggedIn && !note.isSynced) {
                appProvider.syncNotesWithServer();
              }
            } catch (e) {
              if (kDebugMode) print('HomeScreen: 创建笔记失败: $e');
              if (mounted) {
                SnackBarUtils.showError(context, '创建失败: $e');
              }
            }
          }
        },
      ),
    ).then((_) {
      // 🚀 表单关闭（静默）
    });
  }
  
  // 🔥 显示添加笔记表单（带初始内容）- 用于分享接收
  void _showAddNoteFormWithContent(String initialContent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => NoteEditor(
        initialContent: initialContent, // 🔥 预填充分享的内容
        onSave: (content) async {
          if (content.trim().isNotEmpty) {
            try {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final note = await appProvider.createNote(content);
              // 🚀 笔记创建成功（静默）
              
              // 如果用户已登录但笔记未同步，尝试再次同步
              if (appProvider.isLoggedIn && !note.isSynced) {
                appProvider.syncNotesWithServer();
              }
              
              // 显示成功提示
              if (mounted) {
                SnackBarUtils.showSuccess(context, '已添加来自分享的笔记');
              }
            } catch (e) {
              if (kDebugMode) print('HomeScreen: 创建笔记失败: $e');
              if (mounted) {
                SnackBarUtils.showError(context, '创建失败: $e');
              }
            }
          }
        },
      ),
    ).then((_) {
      // 🚀 表单关闭（静默）
    });
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
        currentNoteId: note.id,
        onSave: (content) async {
          if (content.trim().isNotEmpty) {
            try {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              await appProvider.updateNote(note, content);
              // 🚀 笔记更新成功（静默）
              
              // 确保标签更新
              WidgetsBinding.instance.addPostFrameCallback((_) {
                appProvider.notifyListeners(); // 通知所有监听者，确保标签页更新
              });
            } catch (e) {
              if (kDebugMode) print('HomeScreen: 更新笔记失败: $e');
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

  // 构建通知提示框
  Widget _buildNotificationBanner() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);
    
    // 如果没有未读通知，则不显示通知栏
    if (appProvider.unreadAnnouncementsCount <= 0) {
      // 重置自动标记状态，以便下次有新通知时能够自动标记
      _hasAutoMarkedNotificationAsRead = false;
      return const SizedBox.shrink();
    }
    
    // 🎯 用户看到通知后自动标记为已读，避免重复显示（只在第一次显示时执行）
    if (!_hasAutoMarkedNotificationAsRead && appProvider.unreadAnnouncementsCount > 0) {
      _hasAutoMarkedNotificationAsRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          appProvider.markAllAnnouncementsAsRead();
        }
      });
    }
    
    // 设置颜色 - 使用卡片背景色和蓝色主题
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = Colors.blue.shade600;
    final iconColor = Colors.blue.shade600;
        
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // 减少下边距
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // 🎯 直接跳转到通知页面（已读状态已在显示时自动标记）
            if (context.mounted) {
              context.pushNamed('notifications');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isDarkMode ? Colors.black : Colors.black).withOpacity(isDarkMode ? 0.3 : 0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 减少内边距，降低高度
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: iconColor,
                    size: 16, // 减小图标尺寸
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${appProvider.unreadAnnouncementsCount}条未读信息',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w400, // 减轻字重
                      fontSize: 12, // 减小字体
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor;
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    final cardShadow = AppTheme.neuCardShadow(isDark: isDarkMode);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(60),
              boxShadow: cardShadow,
            ),
            child: Center(
              child: Icon(
                Icons.note_add_rounded,
                size: 48,
                color: iconColor.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有笔记',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击右下角的按钮开始创建',
            style: TextStyle(
              fontSize: 16,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSortOrderOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final headerBgColor = isDarkMode 
        ? AppTheme.primaryColor.withOpacity(0.15) 
        : AppTheme.primaryColor.withOpacity(0.05);
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // 获取当前排序方式
    SortOrder currentSortOrder = SortOrder.newest;
    
    // 检查当前排序方式
    if (appProvider.notes.length > 1) {
      if (appProvider.notes[0].createdAt.isAfter(appProvider.notes[1].createdAt)) {
        currentSortOrder = SortOrder.newest;
      } else if (appProvider.notes[0].createdAt.isBefore(appProvider.notes[1].createdAt)) {
        currentSortOrder = SortOrder.oldest;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    '排序方式',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
              RadioListTile<SortOrder>(
                title: Text(
                  '从新到旧',
                  style: TextStyle(color: textColor),
                ),
                value: SortOrder.newest,
                groupValue: currentSortOrder,
                activeColor: iconColor,
                onChanged: (SortOrder? value) {
                  if (value != null) {
                    appProvider.sortNotes(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<SortOrder>(
                title: Text(
                  '从旧到新',
                  style: TextStyle(color: textColor),
            ),
                value: SortOrder.oldest,
                groupValue: currentSortOrder,
                activeColor: iconColor,
                onChanged: (SortOrder? value) {
                  if (value != null) {
                    appProvider.sortNotes(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
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
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor;
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    final hintColor = isDarkMode ? Colors.grey[500] : Colors.grey[400];
    
    return ResponsiveLayout(
      mobile: _buildMobileLayout(backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, hintColor ?? Colors.grey, isDarkMode),
      tablet: _buildTabletLayout(backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, hintColor ?? Colors.grey, isDarkMode),
      desktop: _buildDesktopLayout(backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, hintColor ?? Colors.grey, isDarkMode),
    );
  }

  // 移动端布局
  Widget _buildMobileLayout(Color backgroundColor, Color cardColor, Color textColor, Color secondaryTextColor, Color iconColor, Color hintColor, bool isDarkMode) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Sidebar(),
      backgroundColor: backgroundColor,
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
        title: _isSearchActive
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true, // 自动聚焦，提供更好的用户体验
                decoration: InputDecoration(
                  hintText: '搜索笔记...',
                  hintStyle: TextStyle(
                    color: hintColor,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: iconColor,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(
                  color: textColor,
                ),
                onChanged: (query) {
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  
                  if (query.isEmpty) {
                    // 搜索框为空时，清空搜索结果，这样会显示所有笔记
                    setState(() {
                      _searchResults.clear();
                    });
                    return;
                  }
                  
                  // 执行搜索过滤
                  final results = appProvider.notes.where((note) {
                    return note.content.toLowerCase().contains(query.toLowerCase()) ||
                           note.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
                  }).toList();
                  
                  setState(() {
                    _searchResults = results;
                  });
                },
              ),
            )
          : GestureDetector(
              onTap: _showSortOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                                              AppConfig.appName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 18.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isSearchActive ? Icons.close : Icons.search,
                size: 20,
                color: iconColor,
              ),
            ),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _searchResults.clear();
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        // 点击搜索框外部退出搜索
        onTap: () {
          if (_isSearchActive) {
            setState(() {
              _isSearchActive = false;
              _searchController.clear();
              _searchResults.clear();
            });
            // 取消焦点，隐藏键盘
            FocusScope.of(context).unfocus();
          }
        },
        child: Consumer<AppProvider>(
          builder: (context, appProvider, child) {
          if (appProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: iconColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          
          final notes = _isSearchActive 
              ? (_searchController.text.isEmpty ? appProvider.notes : _searchResults)
              : appProvider.notes;
          
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshNotes,
                      color: AppTheme.primaryColor,
                      child: notes.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                // 添加通知提示框到ListView内部
                                _buildNotificationBanner(),
                                SizedBox(
                                  height: MediaQuery.of(context).size.height - 200,
                                  child: _buildEmptyState(),
                                ),
                              ],
                            )
                          : ListView.builder(
                        controller: _scrollController, // 🚀 添加滚动控制器
                        itemCount: notes.length + 3, // +1通知栏 +1加载指示器 +1底部间距
                        padding: EdgeInsets.zero,
                        cacheExtent: 1000, // 🚀 增加缓存区域，减少重建
                        addAutomaticKeepAlives: true, // 🚀 保持状态，避免滚动时重建
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          // 第一个item是通知栏
                          if (index == 0) {
                            return _buildNotificationBanner();
                          }
                          
                          // 倒数第二个item是加载更多指示器
                          if (index == notes.length + 1) {
                            return _buildLoadMoreIndicator(appProvider);
                          }
                          
                          // 最后一个item是底部间距
                          if (index == notes.length + 2) {
                            return const SizedBox(height: 120);
                          }
                          
                          final note = notes[index - 1]; // 调整索引，因为第一个是通知栏
                          return RepaintBoundary(
                            key: ValueKey(note.id), // 🚀 添加key避免不必要的重建
                            child: NoteCard(
                              key: ValueKey('card_${note.id}'), // 🚀 为NoteCard添加key
                              note: note, // 🚀 直接传递Note对象，避免内部查找
                              onEdit: () {
                                // 🚀 编辑笔记（静默）
                                _showEditNoteForm(note);
                              },
                              onDelete: () async {
                                // 🚀 删除笔记（静默）
                                try {
                                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                                  await appProvider.deleteNote(note.id);
                                  if (context.mounted) {
                                    SnackBarUtils.showSuccess(context, '笔记已删除');
                                  }
                                } catch (e) {
                                  if (kDebugMode) print('HomeScreen: 删除笔记失败: $e');
                                  if (context.mounted) {
                                    SnackBarUtils.showError(context, '删除失败: $e');
                                  }
                                }
                              },
                              onPin: () async {
                                final appProvider = Provider.of<AppProvider>(context, listen: false);
                                await appProvider.togglePinStatus(note);
                                      if (context.mounted) {
                                        SnackBarUtils.showSuccess(context, note.isPinned ? '笔记已置顶' : '笔记已取消置顶');
                                      }
                              },
                            ),
                          );
                        },
                      ),
              ),
              
              // 移除全屏同步覆盖层，改为后台静默同步
                  ],
                ),
              ),
            ],
          );
        },
        ),
      ),
      floatingActionButton: GestureDetector(
        onTapDown: (_) => _fabAnimationController.forward(),
        onTapUp: (_) => _fabAnimationController.reverse(),
        onTapCancel: () => _fabAnimationController.reverse(),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryLightColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAddNoteForm,
                borderRadius: BorderRadius.circular(30),
                splashColor: Colors.white.withOpacity(0.2),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 平板布局
  Widget _buildTabletLayout(Color backgroundColor, Color cardColor, Color textColor, Color secondaryTextColor, Color iconColor, Color hintColor, bool isDarkMode) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Sidebar(),
      backgroundColor: backgroundColor,
      appBar: _buildResponsiveAppBar(backgroundColor, cardColor, textColor, iconColor, hintColor, isDarkMode),
      body: ResponsiveContainer(
        maxWidth: 800,
        child: _buildMainContent(backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, hintColor, isDarkMode),
      ),
      floatingActionButton: _buildResponsiveFAB(isDarkMode),
    );
  }

  // 桌面布局
  Widget _buildDesktopLayout(Color backgroundColor, Color cardColor, Color textColor, Color secondaryTextColor, Color iconColor, Color hintColor, bool isDarkMode) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // 左侧固定侧边栏
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCardColor : AppTheme.surfaceColor,
              border: Border(
                right: BorderSide(
                  color: isDarkMode ? AppTheme.darkDividerColor : AppTheme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: const Sidebar(),
          ),
          // 右侧主内容区域
          Expanded(
            child: Scaffold(
              backgroundColor: backgroundColor,
              appBar: _buildResponsiveAppBar(backgroundColor, cardColor, textColor, iconColor, hintColor, isDarkMode, showDrawerButton: false),
              body: ResponsiveContainer(
                maxWidth: 1000,
                child: _buildMainContent(backgroundColor, cardColor, textColor, secondaryTextColor, iconColor, hintColor, isDarkMode),
              ),
              floatingActionButton: _buildResponsiveFAB(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  // 响应式AppBar
  PreferredSizeWidget _buildResponsiveAppBar(Color backgroundColor, Color cardColor, Color textColor, Color iconColor, Color hintColor, bool isDarkMode, {bool showDrawerButton = true}) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: showDrawerButton ? IconButton(
        icon: Container(
          padding: ResponsiveUtils.responsivePadding(context, all: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveUtils.responsive<double>(context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                height: 2,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 4)),
              Container(
                width: ResponsiveUtils.responsive<double>(context, mobile: 10.0, tablet: 12.0, desktop: 14.0),
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
      ) : null,
      title: _isSearchActive
        ? Container(
            height: ResponsiveUtils.responsive<double>(context, mobile: 40.0, tablet: 44.0, desktop: 48.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(ResponsiveUtils.responsive<double>(context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _performSearch,
              style: TextStyle(
                color: textColor,
                fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
              ),
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                ),
                border: InputBorder.none,
                contentPadding: ResponsiveUtils.responsivePadding(context, horizontal: 16, vertical: 8),
                prefixIcon: Icon(Icons.search, color: hintColor, size: ResponsiveUtils.responsiveIconSize(context, 20)),
              ),
            ),
          )
        : GestureDetector(
            onTap: () => _showAppSelector(),
            child: Container(
              padding: ResponsiveUtils.responsivePadding(context, horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConfig.appName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 18),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 4)),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: textColor,
                    size: ResponsiveUtils.responsiveIconSize(context, 20),
                  ),
                ],
              ),
            ),
          ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: ResponsiveUtils.responsivePadding(context, all: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isSearchActive ? Icons.close : Icons.search,
              size: ResponsiveUtils.responsiveIconSize(context, 20),
              color: iconColor,
            ),
          ),
          onPressed: () {
            setState(() {
              _isSearchActive = !_isSearchActive;
              if (!_isSearchActive) {
                _searchController.clear();
                _searchResults.clear();
              }
            });
          },
        ),
        SizedBox(width: ResponsiveUtils.responsiveSpacing(context, 8)),
      ],
    );
  }

  // 响应式悬浮操作按钮
  Widget _buildResponsiveFAB(bool isDarkMode) {
    final fabSize = ResponsiveUtils.responsive<double>(
      context,
      mobile: 60.0,
      tablet: 68.0,
      desktop: 72.0,
    );
    
    return GestureDetector(
      onTapDown: (_) => _fabAnimationController.forward(),
      onTapUp: (_) => _fabAnimationController.reverse(),
      onTapCancel: () => _fabAnimationController.reverse(),
      child: ScaleTransition(
        scale: _fabScaleAnimation,
        child: Container(
          width: fabSize,
          height: fabSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryLightColor,
              ],
            ),
            borderRadius: BorderRadius.circular(fabSize / 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: ResponsiveUtils.responsive<double>(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAddNoteForm,
              borderRadius: BorderRadius.circular(fabSize / 2),
              splashColor: Colors.white.withOpacity(0.2),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: ResponsiveUtils.responsiveIconSize(context, 32),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 主内容区域
  Widget _buildMainContent(Color backgroundColor, Color cardColor, Color textColor, Color secondaryTextColor, Color iconColor, Color hintColor, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        if (_isSearchActive) {
          setState(() {
            _isSearchActive = false;
            _searchController.clear();
            _searchResults.clear();
          });
          FocusScope.of(context).unfocus();
        }
      },
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          if (appProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: ResponsiveUtils.responsive<double>(context, mobile: 50.0, tablet: 60.0, desktop: 70.0),
                    height: ResponsiveUtils.responsive<double>(context, mobile: 50.0, tablet: 60.0, desktop: 70.0),
                    child: CircularProgressIndicator(
                      color: iconColor,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 16)),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: ResponsiveUtils.responsiveFontSize(context, 16),
                    ),
                  ),
                ],
              ),
            );
          }
          
          final notes = _isSearchActive 
              ? (_searchController.text.isEmpty ? appProvider.notes : _searchResults)
              : appProvider.notes;
          
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshNotes,
                      color: AppTheme.primaryColor,
                      child: notes.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                _buildNotificationBanner(),
                                SizedBox(
                                  height: MediaQuery.of(context).size.height - 200,
                                  child: _buildEmptyState(),
                                ),
                              ],
                            )
                          : ListView.builder(
                        controller: _scrollController, // 🚀 添加滚动控制器
                        itemCount: notes.length + 3, // +1通知栏 +1加载指示器 +1底部间距
                        padding: EdgeInsets.zero,
                        cacheExtent: 1000, // 🚀 增加缓存区域，减少重建
                        addAutomaticKeepAlives: true, // 🚀 保持状态，避免滚动时重建
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildNotificationBanner();
                          }
                          
                          // 倒数第二个item是加载更多指示器
                          if (index == notes.length + 1) {
                            return _buildLoadMoreIndicator(appProvider);
                          }
                          
                          // 最后一个item是底部间距
                          if (index == notes.length + 2) {
                            return SizedBox(height: ResponsiveUtils.responsiveSpacing(context, 120));
                          }
                          
                          final note = notes[index - 1];
                          return RepaintBoundary(
                            key: ValueKey(note.id), // 🚀 添加key避免不必要的重建
                            child: NoteCard(
                              key: ValueKey('card_${note.id}'), // 🚀 为NoteCard添加key
                              note: note, // 🚀 直接传递Note对象，避免内部查找
                              onEdit: () {
                                // 🚀 编辑笔记（静默）
                                _showEditNoteForm(note);
                              },
                              onDelete: () async {
                                // 🚀 删除笔记（静默）
                                try {
                                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                                  await appProvider.deleteNote(note.id);
                                  if (context.mounted) {
                                    SnackBarUtils.showSuccess(context, '笔记已删除');
                                  }
                                } catch (e) {
                                  if (kDebugMode) print('HomeScreen: 删除笔记失败: $e');
                                  if (context.mounted) {
                                    SnackBarUtils.showError(context, '删除失败: $e');
                                  }
                                }
                              },
                              onPin: () async {
                                final appProvider = Provider.of<AppProvider>(context, listen: false);
                                await appProvider.togglePinStatus(note);
                                if (context.mounted) {
                                  SnackBarUtils.showSuccess(context, note.isPinned ? '笔记已置顶' : '笔记已取消置顶');
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 执行搜索（带防抖优化）
  void _performSearch(String query) {
    // 🚀 防抖：取消之前的搜索请求
    _searchDebounce?.cancel();
    
    if (query.isEmpty) {
      // 搜索框为空时，清空搜索结果，这样会显示所有笔记
      setState(() {
        _searchResults.clear();
      });
      return;
    }
    
    // 🚀 延迟300ms执行搜索，避免每次输入都查询
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }
  
  // 实际执行搜索
  Future<void> _executeSearch(String query) async {
    // 🚀 改用数据库搜索，确保搜索全部笔记
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final results = await appProvider.databaseService.searchNotes(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (kDebugMode) print('HomeScreen: 搜索失败: $e');
      // 如果数据库搜索失败，回退到内存搜索
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final results = appProvider.notes.where((note) {
        return note.content.toLowerCase().contains(query.toLowerCase()) ||
               note.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
      }).toList();
      
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    }
  }

  // 显示应用选择器（占位方法）
  void _showAppSelector() {
    // 这是一个占位方法，可以根据需要实现应用选择功能
    // 暂时不做任何操作
  }
  
  // 🚀 构建加载更多指示器
  Widget _buildLoadMoreIndicator(AppProvider appProvider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor;
    
    // 如果还有更多数据，显示加载中
    if (appProvider.hasMoreData) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '加载中...',
              style: TextStyle(
                fontSize: 13,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }
    
    // 没有更多数据，显示已加载全部
    if (appProvider.notes.length > 10) { // 只有笔记数量大于10才显示
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          '已加载全部 ${appProvider.notes.length} 条笔记',
          style: TextStyle(
            fontSize: 12,
            color: textColor.withOpacity(0.6),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
} 