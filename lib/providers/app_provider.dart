import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../main.dart' show navigatorKey;
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../models/app_config_model.dart';
import '../models/sort_order.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/memos_api_service_fixed.dart'; // 使用修复版API服务
import '../services/memos_resource_service.dart'; // 图片上传服务
import '../services/preferences_service.dart';
import '../services/api_service_factory.dart';
import '../services/unified_reference_manager.dart';
import '../config/app_config.dart' as Config;
import '../utils/network_utils.dart';
import '../services/local_reference_service.dart';
import '../services/memos_api_service_fixed.dart' show TokenExpiredException;
import 'package:http/http.dart' as http; // 添加http包
import '../services/announcement_service.dart';
import '../models/announcement_model.dart';
import '../services/cloud_verification_service.dart';
import '../models/cloud_verification_models.dart';
import '../widgets/update_dialog.dart';
import '../services/notification_service.dart';
import '../services/incremental_sync_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/cached_avatar.dart';

class AppProvider with ChangeNotifier {
  User? _user;
  List<Note> _notes = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  
  // 分页加载相关
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 50;
  ApiService? _apiService; // 保留兼容旧服务
  MemosApiServiceFixed? _memosApiService; // 使用修复版API服务
  MemosResourceService? _resourceService; // 图片上传服务
  final DatabaseService _databaseService = DatabaseService();
  final PreferencesService _preferencesService = PreferencesService();
  AppConfig _appConfig = AppConfig();
  bool _mounted = true;
  SortOrder _sortOrder = SortOrder.newest;
  
  // 同步相关变量
  Timer? _syncTimer;
  bool _isSyncing = false;
  String? _syncMessage;
  
  // 通知相关属性
  final AnnouncementService _announcementService = AnnouncementService();
  final CloudVerificationService _cloudService = CloudVerificationService();
  final NotificationService _notificationService = NotificationService();
  // 🔥 暴露notificationService供main.dart使用
  NotificationService get notificationService => _notificationService;
  IncrementalSyncService? _incrementalSyncService;
  int _unreadAnnouncementsCount = 0;
  List<Announcement> _announcements = []; // 公告列表
  // 🔄 已移除 _lastReadAnnouncementId，使用SharedPreferences中的列表管理已读状态
  
  // 云验证相关
  CloudAppConfigData? _cloudAppConfig;
  CloudNoticeData? _cloudNotice;
  DateTime? _lastCloudVerificationTime; // 🚀 上次加载云验证数据的时间
  static const Duration _cloudVerificationCacheDuration = Duration(minutes: 5); // 🚀 缓存5分钟

  // 获取排序后的笔记
  List<Note> _getSortedNotes() {
    final sortedNotes = List<Note>.from(_notes);
    
    // 首先按置顶状态排序，然后按照选择的排序方式排序
    sortedNotes.sort((a, b) {
      // 置顶的笔记始终排在前面
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      
      // 如果两个笔记的置顶状态相同，则按照选择的排序方式排序
      switch (_sortOrder) {
        case SortOrder.newest:
          return b.createdAt.compareTo(a.createdAt);
        case SortOrder.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case SortOrder.updated:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });
    
    return sortedNotes;
  }

  // 设置排序方式
  void setSortOrder(SortOrder sortOrder) {
    if (_sortOrder != sortOrder) {
      _sortOrder = sortOrder;
      notifyListeners();
    }
  }
  
  // Getters
  User? get user => _user;
  List<Note> get notes => _getSortedNotes();
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  
  // 根据ID获取笔记
  Note? getNoteById(String noteId) {
    try {
      return _notes.firstWhere((note) => note.id == noteId);
    } catch (e) {
      return null;
    }
  }
  List<Note> get rawNotes => _notes;
  SortOrder get sortOrder => _sortOrder;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null && _user!.token != null && _user!.token!.isNotEmpty;
  bool get isLocalMode => _appConfig.isLocalMode;
  AppConfig get appConfig => _appConfig;
  ApiService? get apiService => _apiService;
  MemosApiServiceFixed? get memosApiService => _memosApiService;
  MemosResourceService? get resourceService => _resourceService;
  DatabaseService get databaseService => _databaseService;
  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  bool get mounted => _mounted;
  
  int get unreadAnnouncementsCount => _unreadAnnouncementsCount;
  List<Announcement> get announcements => _announcements;
  CloudAppConfigData? get cloudAppConfig => _cloudAppConfig;
  CloudNoticeData? get cloudNotice => _cloudNotice;
  
  /// 更新内存中的笔记（用于本地引用服务通知）
  void updateNoteInMemory(Note updatedNote) {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      notifyListeners();
      // 内存中的笔记已更新
    }
  }

  // 初始化应用
  /// 🔥 单独初始化通知服务（在应用启动时立即调用）
  Future<void> initializeNotificationService() async {
    try {
      print('🚀 [AppProvider] 启动时初始化通知服务...');
      await _notificationService.initialize();
      
      // 设置通知点击回调 - 跳转到笔记详情页并清除提醒
      _notificationService.setNotificationTapCallback((noteIdInt) async {
        if (kDebugMode) {
          print('📱 [AppProvider] 用户点击了通知，noteId: $noteIdInt');
        }
        
        // 🔥 关键修复：使用noteIdMapping找到原始的noteId字符串
        final noteIdString = NotificationService.noteIdMapping[noteIdInt];
        
        if (noteIdString == null) {
          if (kDebugMode) {
            print('❌ [AppProvider] 找不到noteId映射: $noteIdInt');
            print('📋 当前映射表：${NotificationService.noteIdMapping}');
          }
          return;
        }
        
        if (kDebugMode) {
          print('📝 [AppProvider] 映射到笔记ID: $noteIdString');
        }
        
        // 等待一小段时间确保界面完全准备好
        await Future.delayed(const Duration(milliseconds: 300));
        
        // 🔥 关键修复：使用全局的appRouter，不依赖context
        // 需要从main.dart传入appRouter引用，或者使用其他方式获取
        // 暂时先尝试取消提醒
        
        // 🔥 自动清除已触发的提醒（市面上常见做法）
        try {
          await cancelNoteReminder(noteIdString);
          if (kDebugMode) {
            print('✅ [AppProvider] 已自动清除已触发的提醒');
          }
        } catch (error) {
          if (kDebugMode) {
            print('⚠️ [AppProvider] 清除提醒失败: $error');
          }
        }
        
        // TODO: 需要在main.dart中处理跳转，因为这里没有appRouter引用
        if (kDebugMode) {
          print('💡 [AppProvider] 提示：跳转逻辑需要在main.dart中实现');
        }
      });
      
      print('✅ [AppProvider] 通知服务初始化完成');
    } catch (e) {
      print('❌ [AppProvider] 通知服务初始化失败: $e');
    }
  }
  
  Future<void> initializeApp() async {
    if (_isInitialized) return;

    // 开始初始化应用
    
    try {
      // 设置LocalReferenceService的AppProvider引用
      LocalReferenceService.instance.setAppProvider(this);
      
      // 初始化统一引用管理器
      UnifiedReferenceManager().initialize(
        databaseService: _databaseService,
        onNotesUpdated: (updatedNotes) {
          // 分页加载时不直接替换整个列表
          if (_currentPage == 0 && updatedNotes.length <= _pageSize) {
            _notes = updatedNotes;
          } else {
            // 更新已加载的笔记
            for (var note in updatedNotes) {
              final index = _notes.indexWhere((n) => n.id == note.id);
              if (index != -1) {
                _notes[index] = note;
              }
            }
          }
          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) {
            print('UnifiedReferenceManager错误: $error');
          }
        },
        syncReferenceToServerUnified: _syncReferenceToServerUnified,
      );
      
      // 注意：通知服务已在main.dart中提前初始化，这里不需要再次初始化
      
      // 🔥 清理所有过期的提醒
      await clearExpiredReminders();
      
      // 加载应用配置
      // 加载应用配置
      _appConfig = await _preferencesService.loadAppConfig();
      // 应用配置加载完成
      
      // 加载用户信息
      // 加载用户信息
      _user = await _preferencesService.getUser();
      // 用户信息加载完成
      
      // 检查并修复配置状态：如果用户已登录但配置是本地模式，则切换到在线模式
      if (_user != null && _user!.token != null && _appConfig.isLocalMode && _appConfig.memosApiUrl != null) {
        // 检测到已登录用户但配置为本地模式，切换到在线模式
        _appConfig = _appConfig.copyWith(isLocalMode: false);
        await _preferencesService.saveAppConfig(_appConfig);
      }
      
      // 🔄 本地数据优先加载 - 使用分页加载优化性能
      try {
        // 🚀 使用分页加载，只加载首页数据
        await loadInitialNotes();
        // 本地数据首页加载完成
        
        if (kDebugMode) {
          print('AppProvider: ✅ 首页笔记加载完成');
        }
      } catch (e) {
        // 加载本地数据失败
        print('AppProvider: ❌ 加载首页失败: $e');
        _notes = []; // 确保有默认空列表
      }
      
      // 设置初始化标志为true，让UI可以立即显示本地数据
      _isInitialized = true;
      notifyListeners(); // 通知UI更新，此时已经有本地数据可以显示
      
      // 🌐 在后台继续处理网络相关操作，不阻塞UI显示
      _initializeNetworkOperationsInBackground();
      
    } catch (e) {
      // 初始化应用异常
      // 即使出错也确保初始化标志为true，避免卡在启动页
      _isInitialized = true;
      _notes = []; // 确保有默认空列表
      notifyListeners();
    }
  }

  // 后台网络操作初始化（新增方法）
  Future<void> _initializeNetworkOperationsInBackground() async {
    try {
      // 开始后台网络操作初始化
      
      // 异步初始化API服务
      if (_user != null && (_user!.serverUrl != null || _appConfig.memosApiUrl != null)) {
        // 后台初始化API服务
        await _initializeApiServiceInBackground();
      }
      
      // 🔄 延迟扫描引用关系，不阻塞启动
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          rebuildAllReferences().catchError((e) {
            if (kDebugMode) print('AppProvider: 启动时扫描引用关系失败: $e');
          });
        }
      });
      
      // 如果API服务已初始化，尝试获取服务器数据并同步
      if (_memosApiService != null && !_appConfig.isLocalMode) {
                  // 后台从服务器获取最新数据
        fetchNotesFromServer().then((_) {
          // 🔄 服务器数据获取后再次扫描引用关系
          if (kDebugMode) print('AppProvider: 服务器数据获取后重新扫描引用关系');
          return rebuildAllReferences();
        }).catchError((e) {
          if (kDebugMode) print('AppProvider: 后台获取数据失败: $e');
          // 如果获取失败，至少尝试同步本地数据
          syncLocalDataToServer().catchError((e2) {
            if (kDebugMode) print('AppProvider: 后台同步失败: $e2');
          });
        });
      }
      
      // 异步加载通知，不阻塞UI
      if (kDebugMode) print('AppProvider: 异步加载通知');
      refreshAnnouncements().then((_) => refreshUnreadAnnouncementsCount()).catchError((e) {
        if (kDebugMode) print('AppProvider: 加载通知失败: $e');
      });
      
      // 异步加载云验证配置和公告，不阻塞UI
      if (kDebugMode) print('AppProvider: 异步加载云验证数据');
      _loadCloudVerificationData().catchError((e) {
        if (kDebugMode) print('AppProvider: 加载云验证数据失败: $e');
      });
      
      if (kDebugMode) print('AppProvider: 后台网络操作完成');
      
    } catch (e) {
      if (kDebugMode) print('AppProvider: 后台网络操作失败: $e');
    }
  }

  // 服务器端引用同步
  Future<void> _syncReferenceToServerUnified(String sourceId, String targetId, String action) async {
    if (!isLoggedIn || _memosApiService == null || _user?.token == null) {
      if (kDebugMode) {
        // 跳过服务器引用同步（未登录或API服务未初始化）
      }
      return;
    }

    try {
      if (kDebugMode) {
        // 同步引用关系到服务器
      }

      bool success = false;

      if (action == 'CREATE') {
        // 创建引用关系
        final relation = {
          'relatedMemoId': targetId,
          'type': 'REFERENCE',
        };
        success = await _syncSingleReferenceToServer(sourceId, relation);
      } else if (action == 'DELETE') {
        // 删除引用关系 - 先删除所有关系，然后重新创建需要保留的关系
        success = await _deleteAllReferenceRelations(sourceId);
        
        if (success) {
          // 重新创建除了要删除的关系之外的所有引用关系
          final sourceNote = _notes.firstWhere((n) => n.id == sourceId, orElse: () => 
            Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
          
          if (sourceNote.id.isNotEmpty) {
            for (var relation in sourceNote.relations) {
              if (relation['type'] == 'REFERENCE' && 
                  relation['memoId']?.toString() == sourceId &&
                  relation['relatedMemoId']?.toString() != targetId) {
                await _syncSingleReferenceToServer(sourceId, relation);
              }
            }
          }
        }
      }

      if (success) {
        // 更新本地关系的同步状态
        await _markRelationAsSynced(sourceId, targetId, action);
        
        if (kDebugMode) {
          print('AppProvider: ✅ 引用关系服务器同步成功');
        }
      } else {
        if (kDebugMode) {
          print('AppProvider: ❌ 引用关系服务器同步失败');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: ❌ 服务器引用同步异常: $e');
      }
    }
  }

  // 标记引用关系为已同步
  Future<void> _markRelationAsSynced(String sourceId, String targetId, String action) async {
    try {
      // 查找并更新源笔记的关系状态
      final sourceNoteIndex = _notes.indexWhere((n) => n.id == sourceId);
      if (sourceNoteIndex != -1) {
        final sourceNote = _notes[sourceNoteIndex];
        final updatedRelations = sourceNote.relations.map((rel) {
          if (rel['type'] == 'REFERENCE' &&
              rel['memoId']?.toString() == sourceId &&
              rel['relatedMemoId']?.toString() == targetId) {
            return {...rel, 'synced': true};
          }
          return rel;
        }).toList();
        
        final updatedSourceNote = sourceNote.copyWith(relations: updatedRelations);
        await _databaseService.updateNote(updatedSourceNote);
        _notes[sourceNoteIndex] = updatedSourceNote;
      }

      // 查找并更新目标笔记的关系状态
      final targetNoteIndex = _notes.indexWhere((n) => n.id == targetId);
      if (targetNoteIndex != -1) {
        final targetNote = _notes[targetNoteIndex];
        final updatedRelations = targetNote.relations.map((rel) {
          if (rel['type'] == 'REFERENCED_BY' &&
              rel['memoId']?.toString() == sourceId &&
              rel['relatedMemoId']?.toString() == targetId) {
            return {...rel, 'synced': true};
          }
          return rel;
        }).toList();
        
        final updatedTargetNote = targetNote.copyWith(relations: updatedRelations);
        await _databaseService.updateNote(updatedTargetNote);
        _notes[targetNoteIndex] = updatedTargetNote;
      }

      // 刷新UI
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 标记关系为已同步失败: $e');
      }
    }
  }



  // 在后台加载剩余数据
  // 已废弃的 _loadRemainingData 方法，功能已合并到 initializeApp 和 _initializeNetworkOperationsInBackground 中
  
  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // 从本地数据库加载笔记
  Future<void> loadNotesFromLocal({bool reset = false}) async {
    try {
      if (reset) {
        // 重置分页状态，完整加载
        _currentPage = 0;
        _hasMoreData = true;
        _notes = await _databaseService.getNotes();
      } else {
        // 兼容旧代码，完整加载
        _notes = await _databaseService.getNotes();
      }
      
      // 修复失效的图片路径
      bool hasUpdates = await _fixBrokenImagePaths();
      
      // 重新提取所有笔记的标签
      _refreshAllNoteTags();
      
      notifyListeners();
      // 本地笔记加载完成
    } catch (e) {
      print('AppProvider: 从本地加载笔记失败: $e');
      rethrow;
    }
  }
  
  /// 🚀 分页加载初始笔记（性能优化）
  Future<void> loadInitialNotes() async {
    try {
      _currentPage = 0;
      _hasMoreData = true;
      
      // 获取笔记总数
      final totalCount = await _databaseService.getNotesCount();
      print('AppProvider: 笔记总数 $totalCount');
      
      // 首次加载第一页数据
      final firstPage = await _databaseService.getNotesPaged(
        page: 0,
        pageSize: _pageSize,
      );
      
      _notes = firstPage;
      _hasMoreData = totalCount > _pageSize;
      
      // 修复失效的图片路径
      await _fixBrokenImagePaths();
      
      // 重新提取所有笔记的标签
      _refreshAllNoteTags();
      
      notifyListeners();
      print('AppProvider: ✅ 首页加载完成，加载了 ${_notes.length} 条笔记');
    } catch (e) {
      print('AppProvider: 加载初始笔记失败: $e');
      rethrow;
    }
  }
  
  /// 🚀 加载更多笔记（滚动到底部时调用）
  Future<void> loadMoreNotes() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    try {
      _isLoadingMore = true;
      notifyListeners();
      
      _currentPage++;
      print('AppProvider: 加载第 $_currentPage 页笔记...');
      
      final moreNotes = await _databaseService.getNotesPaged(
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      if (moreNotes.isEmpty) {
        _hasMoreData = false;
        print('AppProvider: ✅ 所有笔记已加载完成');
      } else {
        _notes.addAll(moreNotes);
        print('AppProvider: ✅ 第 $_currentPage 页加载完成，新增 ${moreNotes.length} 条笔记');
      }
      
      notifyListeners();
    } catch (e) {
      print('AppProvider: 加载更多笔记失败: $e');
      _currentPage--; // 回退页码
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
  
  // 重新提取所有笔记的标签
  void _refreshAllNoteTags() {
    // 开始重新提取所有笔记的标签
    for (var i = 0; i < _notes.length; i++) {
      var note = _notes[i];
      var tags = extractTags(note.content);
      if (tags.length != note.tags.length || !note.tags.toSet().containsAll(tags)) {
        print('AppProvider: 更新笔记 ${note.id} 的标签: ${note.tags.join(',')} -> ${tags.join(',')}');
        _notes[i] = note.copyWith(tags: tags);
        // 不需要await，批量更新标签只更新内存中的标签，不更新数据库
      }
    }
  }

  // 扫描所有笔记并更新标签（包括数据库更新）
  Future<void> refreshAllNoteTagsWithDatabase() async {
    // 开始扫描所有笔记并更新标签
    _setLoading(true);
    try {
      for (var i = 0; i < _notes.length; i++) {
        var note = _notes[i];
        var tags = extractTags(note.content);
        if (tags.length != note.tags.length || !note.tags.toSet().containsAll(tags)) {
          print('AppProvider: 更新笔记 ${note.id} 的标签: ${note.tags.join(',')} -> ${tags.join(',')}');
          var updatedNote = note.copyWith(tags: tags);
          _notes[i] = updatedNote;
          await _databaseService.updateNote(updatedNote);
        }
      }
      notifyListeners();
    } catch (e) {
      print('AppProvider: 更新所有笔记标签失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 修复失效的图片路径
  Future<bool> _fixBrokenImagePaths() async {
    bool hasUpdates = false;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      
      if (!await imagesDir.exists()) {
        // 图片目录不存在，无需修复
        return false;
      }
      
      // 获取当前应用目录中的所有图片文件
      final imageFiles = await imagesDir.list().where((entity) => entity is File).cast<File>().toList();
      final imageFileNames = imageFiles.map((file) => file.path.split('/').last).toSet();
      
      // 找到图片文件
      
      for (int i = 0; i < _notes.length; i++) {
        final note = _notes[i];
        final imageRegex = RegExp(r'!\[图片\]\(file://([^)]+)\)');
        final matches = imageRegex.allMatches(note.content);
        
        if (matches.isEmpty) continue;
        
        String updatedContent = note.content;
        bool noteUpdated = false;
        
        for (final match in matches) {
          final fullPath = match.group(1)!;
          final fileName = fullPath.split('/').last;
          
          // 检查文件是否存在
          final file = File(fullPath);
          if (!await file.exists()) {
            // 文件不存在，尝试在当前应用目录中找到同名文件
            if (imageFileNames.contains(fileName)) {
              final newPath = '${imagesDir.path}/$fileName';
              final newImageMarkdown = '![图片](file://$newPath)';
              updatedContent = updatedContent.replaceAll(match.group(0)!, newImageMarkdown);
              noteUpdated = true;
              // 修复图片路径
                          } else {
                // 图片文件不存在
              }
          }
        }
        
        if (noteUpdated) {
          final updatedNote = note.copyWith(content: updatedContent);
          _notes[i] = updatedNote;
          await _databaseService.updateNote(updatedNote);
          hasUpdates = true;
        }
      }
      
      if (hasUpdates) {
        // 图片路径修复完成，触发UI刷新
        // 立即触发UI刷新，让修复后的图片显示出来
        notifyListeners();
        
        // 延迟一点时间后再次刷新，确保图片组件重新加载
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_mounted) {
            notifyListeners();
          }
        });
      }
      
    } catch (e) {
      // 修复图片路径失败
    }
    
    return hasUpdates;
  }

  // 计算笔记内容的哈希值
  String _calculateNoteHash(Note note) {
    final content = utf8.encode(note.content);
    final digest = sha256.convert(content);
    return digest.toString();
  }

  // 检查是否存在相同内容的笔记
  Future<bool> _isDuplicateNote(Note note) async {
    final noteHash = _calculateNoteHash(note);
    
    // 检查本地数据库中是否有相同哈希值的笔记
    final allNotes = await _databaseService.getNotes();
    for (var existingNote in allNotes) {
      if (_calculateNoteHash(existingNote) == noteHash) {
        return true;
      }
    }
    
    return false;
  }

  // 检测本地是否有数据
  Future<bool> hasLocalData() async {
    final notes = await _databaseService.getNotes();
    return notes.isNotEmpty;
  }
  
  // 检测云端是否有数据
  Future<bool> hasServerData() async {
    if (!isLoggedIn || _memosApiService == null) return false;
    
    try {
      final response = await _memosApiService!.getMemos();
      final serverNotes = response['memos'] as List<Note>;
      return serverNotes.isNotEmpty;
    } catch (e) {
      print('检查云端数据失败: $e');
      return false;
    }
  }

  // 更新应用配置
  Future<void> updateConfig(AppConfig newConfig) async {
    // 更新配置
    
    // 检查API URL是否变化
    final apiUrlChanged = _appConfig.memosApiUrl != newConfig.memosApiUrl;
    
    // 检查暗黑模式是否变化
    final darkModeChanged = _appConfig.isDarkMode != newConfig.isDarkMode;
    
    // 保存新配置
    _appConfig = newConfig;
    await _preferencesService.saveAppConfig(newConfig);
    
    // 如果API URL变化，重新创建API服务
    if (apiUrlChanged) {
      // API URL已更改，重新创建API服务
      if (newConfig.memosApiUrl != null && newConfig.lastToken != null) {
        _memosApiService = await ApiServiceFactory.createApiService(
          baseUrl: newConfig.memosApiUrl!,
          token: newConfig.lastToken!,
        ) as MemosApiServiceFixed;
      } else {
        _memosApiService = null;
      }
    }
    
    // 如果暗黑模式变化，需要通知界面刷新主题
    if (darkModeChanged) {
      // 暗黑模式已切换
    }
    
    // 配置更新成功
    notifyListeners();
  }
  
  // 获取当前深色模式状态
  bool get isDarkMode {
    // 如果设置了跟随系统，则返回系统深色模式状态
    if (_appConfig.themeSelection == AppConfig.THEME_SYSTEM) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    // 否则根据主题选择返回
    return _appConfig.themeSelection == AppConfig.THEME_DARK;
  }
  
  // 切换深色模式（兼容旧版本）
  Future<void> toggleDarkMode() async {
    final newTheme = isDarkMode ? AppConfig.THEME_LIGHT : AppConfig.THEME_DARK;
    await setThemeSelection(newTheme);
  }
  
  // 设置深色模式（兼容旧版本）
  Future<void> setDarkMode(bool value) async {
    final newTheme = value ? AppConfig.THEME_DARK : AppConfig.THEME_LIGHT;
    await setThemeSelection(newTheme);
  }
  
  // 设置主题选择
  Future<void> setThemeSelection(String themeSelection) async {
    if (themeSelection == _appConfig.themeSelection) return;
    
    // 同时更新isDarkMode以保持向后兼容
    bool isDarkMode = themeSelection == AppConfig.THEME_DARK;
    // 对于跟随系统，需要获取当前系统设置
    if (themeSelection == AppConfig.THEME_SYSTEM) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      isDarkMode = brightness == Brightness.dark;
    }
    
    final updatedConfig = _appConfig.copyWith(
      themeSelection: themeSelection,
      isDarkMode: isDarkMode,
    );
    await updateConfig(updatedConfig);
  }
  
  // 获取当前主题选择
  String get themeSelection => _appConfig.themeSelection;
  
  // 设置主题模式
  Future<void> setThemeMode(String mode) async {
    if (mode == _appConfig.themeMode) return;
    
    final updatedConfig = _appConfig.copyWith(
      themeMode: mode
    );
    await updateConfig(updatedConfig);
  }

  // 获取当前主题模式
  String get themeMode => _appConfig.themeMode;

  // 同步本地数据到云端
  Future<bool> syncLocalToServer() async {
    if (!isLoggedIn || _memosApiService == null) return false;
    
    _setLoading(true);
    
    try {
      // 获取本地笔记
      final localNotes = await _databaseService.getNotes();
      if (localNotes.isEmpty) return true;
      
      // 获取服务器笔记以检查重复
      final response = await _memosApiService!.getMemos();
      final serverNotes = response['memos'] as List<Note>;
      
      // 计算所有服务器笔记的哈希值
      final serverHashes = serverNotes.map(_calculateNoteHash).toSet();
      
      // 同步每个本地笔记到服务器
      int syncedCount = 0;
      for (var note in localNotes) {
        // 如果笔记已经同步，跳过
        if (note.isSynced) continue;
        
        // 计算本地笔记的哈希值
        final noteHash = _calculateNoteHash(note);
        
        // 如果服务器上已有相同内容的笔记，跳过
        if (serverHashes.contains(noteHash)) {
          // 标记为已同步
          note.isSynced = true;
          await _databaseService.updateNote(note);
          continue;
        }
        
        try {
          // 创建服务器笔记
          final serverNote = await _memosApiService!.createMemo(
            content: note.content,
            visibility: note.visibility,
          );
          
          // 更新本地笔记的同步状态
          final updatedNote = note.copyWith(
            isSynced: true,
          );
          
          // 更新数据库
          await _databaseService.updateNote(updatedNote);
          
          syncedCount++;
        } catch (e) {
          print('同步笔记失败: ${note.id} - $e');
        }
      }
      
      // 刷新内存中的列表
      await loadNotesFromLocal();
      
      print('成功同步 $syncedCount 条笔记到云端');
      return true;
    } catch (e) {
      print('同步本地数据到云端失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 同步云端数据到本地
  Future<bool> syncServerToLocal() async {
    if (!isLoggedIn || _memosApiService == null) return false;
    
    _setLoading(true);
    
    try {
      // 获取服务器笔记
      final response = await _memosApiService!.getMemos();
      final serverNotes = response['memos'] as List<Note>;
      if (serverNotes.isEmpty) return true;
      
      // 获取本地笔记以检查重复
      final localNotes = await _databaseService.getNotes();
      
      // 计算所有本地笔记的哈希值
      final localHashes = localNotes.map(_calculateNoteHash).toSet();
      
      // 同步每个服务器笔记到本地
      int syncedCount = 0;
      for (var serverNote in serverNotes) {
        // 计算服务器笔记的哈希值
        final noteHash = _calculateNoteHash(serverNote);
        
        // 如果本地已有相同内容的笔记，跳过
        if (localHashes.contains(noteHash)) {
          continue;
        }
        
        // 保存到本地数据库
        await _databaseService.saveNote(serverNote);
        syncedCount++;
      }
      
      // 刷新内存中的列表
      await loadNotesFromLocal();
      
      print('成功同步 $syncedCount 条笔记到本地');
      return true;
    } catch (e) {
      print('同步云端数据到本地失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 使用账号密码注册
  Future<(bool, String?)> registerWithPassword(String serverUrl, String username, String password, {bool remember = false}) async {
    try {
      print('AppProvider: 尝试注册账号 - URL: $serverUrl, 用户名: $username');
      
      // 规范化URL（确保末尾没有斜杠）
      final normalizedUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      
      print('AppProvider: 规范化后的URL: $normalizedUrl');
      
      // 调用注册API
      final response = await http.post(
        Uri.parse('$normalizedUrl/api/v1/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      print('AppProvider: 注册API响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('AppProvider: 注册成功，尝试自动登录');
        
        // 注册成功后自动登录
        final loginResult = await loginWithPassword(
          serverUrl,
          username,
          password,
          remember: remember,
        );
        
        if (loginResult.$1) {
          print('AppProvider: 注册并登录成功');
          return (true, null);
        } else {
          print('AppProvider: 注册成功但自动登录失败: ${loginResult.$2}');
          return (false, '注册成功，请手动登录');
        }
      } else {
        final errorData = jsonDecode(response.body);
        final serverMessage = errorData['message']?.toString() ?? '';
        String userFriendlyMessage;
        
        // 根据HTTP状态码和服务器消息提供用户友好的错误提示
        switch (response.statusCode) {
          case 400:
            if (serverMessage.toLowerCase().contains('invalid username')) {
              userFriendlyMessage = '用户名格式不正确\n只能包含字母、数字、下划线和连字符';
            } else if (serverMessage.toLowerCase().contains('username') && 
                serverMessage.toLowerCase().contains('exists')) {
              userFriendlyMessage = '用户名已存在，请选择其他用户名';
            } else if (serverMessage.toLowerCase().contains('password')) {
              userFriendlyMessage = '密码不符合要求，请重新设置';
            } else if (serverMessage.toLowerCase().contains('failed to create user')) {
              userFriendlyMessage = '创建用户失败，用户名可能已存在';
            } else {
              userFriendlyMessage = '注册信息有误，请检查后重试';
            }
            break;
          case 401:
            if (serverMessage.toLowerCase().contains('signup is disabled') || 
                serverMessage.toLowerCase().contains('disallow')) {
              userFriendlyMessage = '该服务器已禁用用户注册功能\n请联系管理员或使用现有账号登录';
            } else if (serverMessage.toLowerCase().contains('password login is deactivated')) {
              userFriendlyMessage = '该服务器已禁用密码登录功能\n请联系管理员';
            } else {
              userFriendlyMessage = '注册功能已被管理员禁用，请联系管理员';
            }
            break;
          case 403:
            userFriendlyMessage = '注册功能已被管理员禁用，请联系管理员';
            break;
          case 409:
            userFriendlyMessage = '用户名已被占用，请选择其他用户名';
            break;
          case 429:
            userFriendlyMessage = '注册请求过于频繁，请稍后再试';
            break;
          case 500:
            if (serverMessage.toLowerCase().contains('failed to create user')) {
              userFriendlyMessage = '创建用户失败，可能是用户名已存在或服务器配置问题';
            } else if (serverMessage.toLowerCase().contains('failed to generate password hash')) {
              userFriendlyMessage = '密码处理失败，请重新尝试';
            } else {
              userFriendlyMessage = '服务器内部错误，请稍后重试或联系管理员';
            }
            break;
          case 503:
            userFriendlyMessage = '服务器暂时不可用，请稍后重试';
            break;
          default:
            userFriendlyMessage = '注册失败，请检查网络连接和服务器地址';
        }
        
        print('AppProvider: 注册失败: $serverMessage');
        return (false, userFriendlyMessage);
      }
      
    } catch (e) {
      print('AppProvider: 注册异常: $e');
      String userFriendlyMessage;
      
      // 根据异常类型提供用户友好的错误提示
      if (e.toString().contains('SocketException') || 
          e.toString().contains('NetworkException')) {
        userFriendlyMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('TimeoutException')) {
        userFriendlyMessage = '连接超时，请检查网络或稍后重试';
      } else if (e.toString().contains('FormatException') || 
                 e.toString().contains('Invalid')) {
        userFriendlyMessage = '服务器响应格式错误，请检查服务器地址';
      } else if (e.toString().contains('HandshakeException') || 
                 e.toString().contains('TlsException')) {
        userFriendlyMessage = 'SSL连接失败，请检查服务器证书';
      } else {
        userFriendlyMessage = '注册失败，请检查服务器地址和网络连接';
      }
      
      return (false, userFriendlyMessage);
    }
  }

  // 使用账号密码登录
  Future<(bool, String?)> loginWithPassword(String serverUrl, String username, String password, {bool remember = false}) async {
    try {
      print('AppProvider: 尝试使用账号密码登录 - URL: $serverUrl, 用户名: $username');
      
      // 规范化URL（确保末尾没有斜杠）
      final normalizedUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      
      print('AppProvider: 规范化后的URL: $normalizedUrl');
      
      // 构建请求体
      final requestBody = {
        'username': username,
        'password': password,
        'remember': remember,
      };
      print('AppProvider: 登录请求体: ${jsonEncode(requestBody)}');
      
      // 调用登录API
      final response = await http.post(
        Uri.parse('$normalizedUrl/api/v1/auth/signin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('AppProvider: 登录API响应状态: ${response.statusCode}');
      print('AppProvider: 登录API响应头: ${response.headers}');
      print('AppProvider: 登录API响应体: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('AppProvider: 登录成功，解析用户信息');
        
        // 从响应头获取Token（可能在Set-Cookie中）
        String? token;
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          // 解析Cookie中的memos.access-token（注意Cookie名称包含memos.前缀）
          final cookieRegex = RegExp(r'memos\.access-token=([^;]+)');
          final match = cookieRegex.firstMatch(cookies);
          if (match != null) {
            token = match.group(1);
            print('AppProvider: 从Cookie中提取Token: ${token?.substring(0, 10)}...');
          }
        }
        
        // 如果没有从Cookie中获取到Token，尝试从响应体中获取
        if (token == null && responseData['accessToken'] != null) {
          token = responseData['accessToken'];
          print('AppProvider: 从响应体中获取Token: ${token?.substring(0, 10)}...');
        }
        
        if (token == null) {
          throw Exception('登录成功但无法获取访问令牌，请重试或联系管理员');
        }
        
        // 创建用户对象
        final user = User(
          id: responseData['id']?.toString() ?? '',
          username: responseData['username'] ?? username,
          email: responseData['email'] ?? '',
          nickname: responseData['nickname'] ?? responseData['username'] ?? username,
          avatarUrl: responseData['avatarUrl'],
          role: responseData['role'] ?? 'USER',
          token: token,
        );
        
        // 保存用户信息到持久化存储和内存
        await _preferencesService.saveUser(user);
        _user = user;
        
        // 注意：新token登录成功后，服务器端的旧token应该会自动失效
        // 这是大多数现代认证系统的标准行为
        // 如果服务器不支持自动撤销旧token，可以考虑：
        // 1. 在登录前调用logout API撤销旧token（需要旧token仍有效）
        // 2. 设置更短的token过期时间  
        // 3. 要求服务器端实现单点登录机制
        
        // 更新应用配置
        _appConfig = _appConfig.copyWith(
          memosApiUrl: normalizedUrl,
          lastToken: remember ? token : null,
          lastUsername: remember ? username : null,
          lastServerUrl: normalizedUrl,
          rememberLogin: remember,
          autoLogin: true, // 登录成功后自动开启自动登录
          isLocalMode: false, // 登录成功后切换到在线模式
        );
        
        // 保存配置更新
        await _preferencesService.saveAppConfig(_appConfig);
        
        // 如果选择记住登录，保存到安全存储
        if (remember) {
          await saveLoginInfo(normalizedUrl, username, token: token, password: password);
        }
        
        // 初始化API服务
        _memosApiService = await ApiServiceFactory.createApiService(
          baseUrl: normalizedUrl,
          token: token,
        ) as MemosApiServiceFixed;
        
        // 初始化资源服务
        _resourceService = MemosResourceService(
          baseUrl: normalizedUrl,
          token: token,
        );
        
        print('AppProvider: 账号密码登录成功');
        notifyListeners();
        
        // 🖼️ 预加载用户头像（提升用户体验）
        _preloadUserAvatarAsync();
        
        return (true, null);
        
      } else {
        final errorData = jsonDecode(response.body);
        final serverMessage = errorData['message']?.toString() ?? '';
        String userFriendlyMessage;
        
        // 根据HTTP状态码和服务器消息提供用户友好的错误提示
        switch (response.statusCode) {
          case 401:
            if (serverMessage.toLowerCase().contains('password') || 
                serverMessage.toLowerCase().contains('credentials')) {
              userFriendlyMessage = '用户名或密码错误，请检查后重试';
            } else if (serverMessage.toLowerCase().contains('deactivated')) {
              userFriendlyMessage = '密码登录已被管理员禁用，请联系管理员';
            } else {
              userFriendlyMessage = '账号或密码不正确';
            }
            break;
          case 403:
            if (serverMessage.toLowerCase().contains('archived')) {
              userFriendlyMessage = '该账号已被停用，请联系管理员';
            } else {
              userFriendlyMessage = '账号被禁止登录，请联系管理员';
            }
            break;
          case 404:
            userFriendlyMessage = '服务器地址不正确或服务不可用';
            break;
          case 429:
            userFriendlyMessage = '登录尝试过于频繁，请稍后再试';
            break;
          case 500:
            userFriendlyMessage = '服务器内部错误，请稍后重试或联系管理员';
            break;
          case 503:
            userFriendlyMessage = '服务器暂时不可用，请稍后重试';
            break;
          default:
            userFriendlyMessage = '登录失败，请检查网络连接和服务器地址';
        }
        
        print('AppProvider: 登录失败 - 状态码: ${response.statusCode}');
        print('AppProvider: 服务器原始消息: $serverMessage');
        print('AppProvider: 完整响应体: ${response.body}');
        return (false, userFriendlyMessage);
      }
      
    } catch (e) {
      print('AppProvider: 账号密码登录失败: $e');
      String userFriendlyMessage;
      
      // 根据异常类型提供用户友好的错误提示
      if (e.toString().contains('SocketException') || 
          e.toString().contains('NetworkException')) {
        userFriendlyMessage = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('TimeoutException')) {
        userFriendlyMessage = '连接超时，请检查网络或稍后重试';
      } else if (e.toString().contains('FormatException') || 
                 e.toString().contains('Invalid')) {
        userFriendlyMessage = '服务器响应格式错误，请检查服务器地址';
      } else if (e.toString().contains('HandshakeException') || 
                 e.toString().contains('TlsException')) {
        userFriendlyMessage = 'SSL连接失败，请检查服务器证书';
      } else {
        userFriendlyMessage = '登录失败，请检查服务器地址和网络连接';
      }
      
      return (false, userFriendlyMessage);
    }
  }

  // 使用Token登录
  Future<(bool, String?)> loginWithToken(String serverUrl, String token, {bool remember = false}) async {
    try {
      print('AppProvider: 尝试使用Token登录 - URL: $serverUrl');
      
      // 规范化URL（确保末尾没有斜杠）
      final normalizedUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      
      print('AppProvider: 规范化后的URL: $normalizedUrl');
      
      // 初始化API服务
      _memosApiService = await ApiServiceFactory.createApiService(
        baseUrl: normalizedUrl,
        token: token,
      ) as MemosApiServiceFixed;
      
      // 初始化资源服务
      _resourceService = MemosResourceService(
        baseUrl: normalizedUrl,
        token: token,
      );
      
      // 验证Token
      try {
        // 先尝试 v1 API
        print('AppProvider: 尝试访问 v1 API: $normalizedUrl/api/v1/user/me');
        final response = await http.get(
          Uri.parse('$normalizedUrl/api/v1/user/me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print('AppProvider: v1 API响应状态码: ${response.statusCode}');
        print('AppProvider: v1 API响应内容: ${response.body}');
        
        if (response.statusCode == 200) {
          try {
            final userInfo = jsonDecode(response.body);
            print('AppProvider: 解析到的用户信息: $userInfo');
            
            // 检查响应格式
            if (userInfo == null) {
              throw Exception('服务器返回空数据');
            }

            User? user;
            if (userInfo['data'] != null) {
              // 新版API格式
              print('AppProvider: 使用新版API格式解析');
              final userData = userInfo['data'];
              user = User(
                id: userData['id'].toString(),
                username: userData['username'] as String? ?? '',
                nickname: userData['nickname'] as String?,
                email: userData['email'] as String?,
                avatarUrl: userData['avatarUrl'] as String?,
                description: userData['description'] as String?,
                role: (userData['role'] as String?) ?? 'USER',
                token: token,
                lastSyncTime: DateTime.now(),
              );
            } else {
              // 旧版API格式
              print('AppProvider: 使用旧版API格式解析');
              user = User(
                id: userInfo['id'].toString(),
                username: userInfo['username'] as String? ?? '',
                nickname: userInfo['nickname'] as String?,
                email: userInfo['email'] as String?,
                avatarUrl: userInfo['avatarUrl'] as String?,
                description: userInfo['description'] as String?,
                role: (userInfo['role'] as String?) ?? 'USER',
                token: token,
                lastSyncTime: DateTime.now(),
              );
            }
            
            // 保存用户信息
            await _preferencesService.saveUser(user);
            _user = user;
            
            // 更新配置
            final updatedConfig = _appConfig.copyWith(
              memosApiUrl: normalizedUrl,
              lastToken: remember ? token : null,
              rememberLogin: remember,
              isLocalMode: false,
            );
            await updateConfig(updatedConfig);
            
            print('AppProvider: Token登录成功');
            
            // 🖼️ 预加载用户头像（提升用户体验）
            _preloadUserAvatarAsync();
            
            // 检查本地是否有未同步笔记
            final hasLocalNotes = await hasLocalData();
            if (hasLocalNotes) {
              print('AppProvider: 检测到本地有笔记数据，需要同步');
            }
            
            return (true, null);
          } catch (e, stackTrace) {
            print('AppProvider: 解析用户信息失败: $e');
            print('AppProvider: 错误堆栈: $stackTrace');
            throw Exception('解析用户信息失败: $e');
          }
        } else if (response.statusCode == 404 || response.statusCode == 401) {
          // 如果v1 API不存在或未授权，尝试旧版API
          print('AppProvider: v1 API返回 ${response.statusCode}，尝试旧版API');
          print('AppProvider: 尝试访问旧版API: $normalizedUrl/api/user/me');
          
          final oldResponse = await http.get(
            Uri.parse('$normalizedUrl/api/user/me'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          print('AppProvider: 旧版API响应状态码: ${oldResponse.statusCode}');
          print('AppProvider: 旧版API响应内容: ${oldResponse.body}');

          if (oldResponse.statusCode == 200) {
            try {
              final userInfo = jsonDecode(oldResponse.body);
              print('AppProvider: 解析到的用户信息（旧版API）: $userInfo');
              
              final user = User(
                id: userInfo['id'].toString(),
                username: userInfo['username'] as String? ?? '',
                nickname: userInfo['nickname'] as String?,
                email: userInfo['email'] as String?,
                avatarUrl: userInfo['avatarUrl'] as String?,
                description: userInfo['description'] as String?,
                role: (userInfo['role'] as String?) ?? 'USER',
                token: token,
                lastSyncTime: DateTime.now(),
              );
              
              // 保存用户信息
              await _preferencesService.saveUser(user);
              _user = user;
              
              // 更新配置
              final updatedConfig = _appConfig.copyWith(
                memosApiUrl: normalizedUrl,
                lastToken: remember ? token : null,
                rememberLogin: remember,
                isLocalMode: false,
              );
              await updateConfig(updatedConfig);
              
              print('AppProvider: Token登录成功（旧版API）');
              
              // 检查本地是否有未同步笔记
              final hasLocalNotes = await hasLocalData();
              if (hasLocalNotes) {
                print('AppProvider: 检测到本地有笔记数据，需要同步');
              }
              
              return (true, null);
            } catch (e, stackTrace) {
              print('AppProvider: 解析用户信息失败（旧版API）: $e');
              print('AppProvider: 错误堆栈: $stackTrace');
              throw Exception('解析用户信息失败（旧版API）: $e');
            }
          } else {
            throw Exception('获取用户信息失败: ${oldResponse.statusCode}');
          }
        } else {
          throw Exception('获取用户信息失败: ${response.statusCode}');
        }
      } catch (e, stackTrace) {
        print('AppProvider: 验证Token失败: $e');
        print('AppProvider: 错误堆栈: $stackTrace');
        throw Exception('验证Token失败: $e');
      }
    } catch (e, stackTrace) {
      print('AppProvider: Token登录失败: $e');
      print('AppProvider: 错误堆栈: $stackTrace');
      return (false, e.toString());
    }
  }
  
  // 登录后检查本地数据并提示用户是否需要同步
  Future<void> checkAndSyncOnLogin() async {
    try {
      print('AppProvider: 登录后检查本地数据');
      
      // 检查本地和服务器是否有数据
      final hasLocalData = await this.hasLocalData();
      final hasServerData = await this.hasServerData();
      
      if (hasLocalData) {
        print('AppProvider: 检测到本地有数据');
        
        // 本地有数据，从服务器获取数据时会自动保留本地未同步的笔记
        // fetchNotesFromServer方法已经被修改，会处理本地未同步笔记
        await fetchNotesFromServer();
        
        // 这里已经不需要返回状态让UI处理了，因为修改后的同步流程会自动处理
        return;
      } else {
        print('AppProvider: 本地无数据，直接获取服务器数据');
        // 直接获取服务器数据
        await fetchNotesFromServer();
      }
    } catch (e) {
      print('AppProvider: 检查同步状态失败: $e');
      // 出错时，至少确保加载了数据
      await loadNotesFromLocal();
    }
  }
  
  // 同步本地引用关系到服务器
  Future<int> syncLocalReferencesToServer() async {
    if (!isLoggedIn || _memosApiService == null) {
      if (kDebugMode) print('AppProvider: 未登录或API服务未初始化，无法同步引用关系');
      return 0;
    }
    
    try {
      final localRefService = LocalReferenceService.instance;
      final unsyncedRefs = await localRefService.getUnsyncedReferences();
      
      if (unsyncedRefs.isEmpty) {
        if (kDebugMode) print('AppProvider: 没有未同步的引用关系');
        return 0;
      }
      
      if (kDebugMode) {
        print('AppProvider: 开始同步 ${unsyncedRefs.length} 个引用关系到服务器');
      }
      
      int syncedCount = 0;
      for (final refData in unsyncedRefs) {
        try {
          final noteId = refData['noteId'] as String;
          final relation = refData['relation'] as Map<String, dynamic>;
          
          // 调用服务器API同步引用关系
          final success = await _syncSingleReferenceToServer(noteId, relation);
          
          if (success) {
            // 标记为已同步
            await localRefService.markReferenceAsSynced(noteId, relation);
            syncedCount++;
          }
        } catch (e) {
          if (kDebugMode) {
            print('AppProvider: 同步引用关系失败: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('AppProvider: 成功同步 $syncedCount 个引用关系');
      }
      
      return syncedCount;
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 同步引用关系异常: $e');
      }
      return 0;
    }
  }
  
  // 同步单个引用关系到服务器 (使用v1 API)
  Future<bool> _syncSingleReferenceToServer(String noteId, Map<String, dynamic> relation) async {
    try {
      final relatedMemoId = relation['relatedMemoId']?.toString();
      if (relatedMemoId == null) return false;
      
      // 使用v1 API: POST /api/v1/memo/{memoId}/relation
      final url = '${_appConfig.memosApiUrl}/api/v1/memo/$noteId/relation';
      final headers = {
        'Authorization': 'Bearer ${_user!.token}',
        'Content-Type': 'application/json',
      };
      
      final body = {
        'relatedMemoId': int.parse(relatedMemoId),
        'type': 'REFERENCE',
      };
      
      final response = await NetworkUtils.directPost(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (kDebugMode) {
        print('AppProvider: 同步引用关系 $noteId -> $relatedMemoId, 状态: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('AppProvider: 引用关系同步成功');
        } else {
          print('AppProvider: 引用关系同步失败，响应: ${response.body}');
        }
      }
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 同步单个引用关系失败: $e');
      }
      return false;
    }
  }
  
  // 从服务器获取单个memo的引用关系
  Future<List<Map<String, dynamic>>> _fetchMemoRelationsFromServer(String memoId) async {
    try {
      // 使用v1 API: GET /api/v1/memo/{memoId}/relation
      final url = '${_appConfig.memosApiUrl}/api/v1/memo/$memoId/relation';
      final headers = {
        'Authorization': 'Bearer ${_user!.token}',
        'Content-Type': 'application/json',
      };
      
      final client = http.Client();
      final response = await client.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(Duration(seconds: 30));
      client.close();
      
      if (response.statusCode == 200) {
        final List<dynamic> relations = jsonDecode(response.body);
        final List<Map<String, dynamic>> formattedRelations = [];
        
        for (var relation in relations) {
          // 转换为我们的格式，确保包含所有必要字段
          formattedRelations.add({
            'memoId': relation['memoId'], // 确保包含memoId
            'relatedMemoId': relation['relatedMemoId'],
            'type': relation['type'],
          });
        }
        
        if (kDebugMode && formattedRelations.isNotEmpty) {
          print('AppProvider: 从服务器获取笔记 $memoId 的引用关系: ${formattedRelations.length} 个');
        }
        
        return formattedRelations;
      } else {
        if (kDebugMode) {
          print('AppProvider: 获取笔记 $memoId 引用关系失败，状态码: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 获取笔记 $memoId 引用关系异常: $e');
      }
      return [];
    }
  }

  // 同步本地数据到服务器
  Future<bool> syncLocalDataToServer() async {
    // 后台静默同步，不显示状态
    
    if (!isLoggedIn || _memosApiService == null) {
      print('AppProvider: 未登录或API服务未初始化，无法同步');
      // 后台同步失败，静默处理
      return false;
    }

    try {
      print('AppProvider: 开始同步本地数据到云端');
      
      // 获取本地未同步的笔记（后台执行）
      
      final unsyncedNotes = await _databaseService.getUnsyncedNotes();
      print('AppProvider: 发现 ${unsyncedNotes.length} 条未同步的笔记');

      if (unsyncedNotes.isEmpty) {
                  // 所有笔记已同步（静默处理）
        
        return true;
      }

      int syncedCount = 0;
      for (int i = 0; i < unsyncedNotes.length; i++) {
        final note = unsyncedNotes[i];
        // 正在后台同步笔记 ${i + 1}/${unsyncedNotes.length}
        
        try {
          if (note.id.startsWith('local_')) {
            // 新建笔记
            final createdNote = await _memosApiService!.createMemo(
              content: note.content,
              visibility: note.visibility,
            );
            await _databaseService.updateNoteServerId(
              note.id,
              createdNote.id,
            );
            syncedCount++;
          } else {
            // 更新笔记
            await _memosApiService!.updateMemo(
              note.id,
              content: note.content,
              visibility: note.visibility,
            );
            await _databaseService.markNoteSynced(note.id);
            syncedCount++;
          }
        } catch (e) {
          print('AppProvider: 同步笔记失败: ${note.id}, 错误: $e');
          continue;
        }
      }

      print('AppProvider: 成功同步 $syncedCount 条笔记到云端');
      
      // 同步引用关系
      _syncMessage = '同步引用关系...';
      notifyListeners();
      
      final refSyncedCount = await syncLocalReferencesToServer();
      if (refSyncedCount > 0) {
        print('AppProvider: 成功同步 $refSyncedCount 个引用关系到云端');
      }
      
      // 从服务器获取最新数据
      // 后台刷新最新数据
      
      await fetchNotesFromServer();
      
      // 后台同步完成
      
      return true;
    } catch (e) {
      print('AppProvider: 后台同步失败: $e');
      // 同步失败也静默处理，不影响用户体验
      return false;
    }
  }

  // 从文本内容中提取标签
  List<String> extractTags(String content) {
    final RegExp tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    final matches = tagRegex.allMatches(content);
    
    return matches
      .map((match) => match.group(1))
      .where((tag) => tag != null)
      .map((tag) => tag!)
      .toList();
  }

  // 获取所有标签
  Set<String> getAllTags() {
    Set<String> tags = {};
    for (var note in _notes) {
      tags.addAll(note.tags);
    }
    return tags;
  }

  // 排序笔记
  void sortNotes(SortOrder order) {
    switch (order) {
      case SortOrder.newest:
        _notes.sort((a, b) {
          // 先按是否置顶排序，置顶的在前面
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          // 再按创建时间排序
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case SortOrder.oldest:
        _notes.sort((a, b) {
          // 先按是否置顶排序，置顶的在前面
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          // 再按创建时间排序
          return a.createdAt.compareTo(b.createdAt);
        });
        break;
      case SortOrder.updated:
        _notes.sort((a, b) {
          // 先按是否置顶排序，置顶的在前面
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          // 再按更新时间排序
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
    }
    notifyListeners();
  }

  // 切换笔记的置顶状态
  Future<bool> togglePinStatus(Note note) async {
    try {
      // 切换置顶状态
      final updatedNote = note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
      );
      
      // 更新本地数据库
      await _databaseService.updateNote(updatedNote);
      
      // 如果是在线模式且已登录，尝试同步到服务器
      if (!_appConfig.isLocalMode && isLoggedIn && _memosApiService != null) {
        try {
          // 这里应该调用相应的API来更新笔记的置顶状态
          final serverNote = await _memosApiService!.updateMemo(
            note.id,
            content: note.content,
            visibility: note.visibility,
          );
          
          // 更新本地数据库
          final syncedNote = serverNote.copyWith(
            isPinned: updatedNote.isPinned,
            isSynced: true,
          );
          await _databaseService.updateNote(syncedNote);
          
          // 更新内存中的列表
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = syncedNote;
          }
        } catch (e) {
          print('同步置顶状态到服务器失败: $e');
        }
      }
      
      // 更新内存中的列表
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
      }
      
      // 重新排序笔记列表
      final currentOrder = _getCurrentSortOrder();
      sortNotes(currentOrder);
      
      return true;
    } catch (e) {
      print('切换置顶状态失败: $e');
      return false;
    }
  }

  // 获取当前的排序方式
  SortOrder _getCurrentSortOrder() {
    if (_notes.length < 2) return SortOrder.newest;
    
    // 忽略置顶状态，仅根据时间判断排序方式
    List<Note> unpinnedNotes = _notes.where((note) => !note.isPinned).toList();
    if (unpinnedNotes.length < 2) return SortOrder.newest;
    
    if (unpinnedNotes[0].createdAt.isAfter(unpinnedNotes[1].createdAt)) {
      return SortOrder.newest;
    } else if (unpinnedNotes[0].createdAt.isBefore(unpinnedNotes[1].createdAt)) {
      return SortOrder.oldest;
    } else if (unpinnedNotes[0].updatedAt.isAfter(unpinnedNotes[1].updatedAt)) {
      return SortOrder.updated;
    }
    
    return SortOrder.newest; // 默认返回最新排序
  }

  // 切换到本地模式
  Future<void> switchToLocalMode() async {
    _appConfig = _appConfig.copyWith(isLocalMode: true);
    await _preferencesService.saveAppConfig(_appConfig);
    notifyListeners();
  }

  // 退出登录
  Future<(bool, String?)> logout({bool force = false, bool keepLocalData = true}) async {
    if (!force) {
      _setLoading(true);
    } else {
      // 设置同步状态
      _isSyncing = true;
      _syncMessage = '正在处理退出登录...';
      notifyListeners();
    }
    
    try {
      // 检查是否有未同步的笔记
      if (!force && !_appConfig.isLocalMode && isLoggedIn) {
        final unsyncedNotes = await _databaseService.getUnsyncedNotes();
        if (unsyncedNotes.isNotEmpty) {
          _setLoading(false);
          return (false, "有${unsyncedNotes.length}条笔记未同步到云端，退出登录后这些笔记将无法同步。确定要退出吗？");
        }
      }
      
      // 如果不保留本地数据，则清空数据库
      if (!keepLocalData) {
        _syncMessage = '清空本地数据库...';
        notifyListeners();
        
        print('AppProvider: 清空本地数据库');
        await _databaseService.clearAllNotes();
      } else {
        _syncMessage = '保存本地数据...';
        notifyListeners();
        
        print('AppProvider: 保留本地数据');
      }
      
      // 取消同步定时器
      _syncTimer?.cancel();
      _syncTimer = null;
      
      // 🔐 在清除本地信息前，先撤销服务器端的token
      if (_memosApiService != null && !_appConfig.isLocalMode) {
        _syncMessage = '撤销服务器token...';
        notifyListeners();
        
        try {
          await _memosApiService!.logout();
          if (kDebugMode) print('AppProvider: 服务器token撤销成功');
        } catch (e) {
          if (kDebugMode) print('AppProvider: 服务器token撤销失败: $e');
          // 继续执行，不阻塞登出流程
        }
      }
      
      // 清除用户信息
      _user = null;
      await _preferencesService.clearUser();
      
      _syncMessage = '更新配置...';
      notifyListeners();
      
      // 更新配置为本地模式，但保留记住的登录信息
      final bool rememberLogin = _appConfig.rememberLogin;
      final String? lastToken = rememberLogin ? _appConfig.lastToken : null;
      final String? lastServerUrl = rememberLogin ? _appConfig.lastServerUrl : null;
      
      _appConfig = _appConfig.copyWith(
        isLocalMode: true,
        // 如果之前选择了记住登录，则保留这些信息
        rememberLogin: rememberLogin,
        lastToken: lastToken,
        lastServerUrl: lastServerUrl,
      );
      await _preferencesService.saveAppConfig(_appConfig);
      
      // 清除API服务
      _apiService = null;
      _memosApiService = null;
      
      // 重新加载本地笔记
      if (keepLocalData) {
        _syncMessage = '加载本地笔记...';
        notifyListeners();
        
        await loadNotesFromLocal();
      } else {
        _notes = [];
      }
      
      _syncMessage = '退出登录完成';
      notifyListeners();
      
      // 延迟一点时间再清除同步状态
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          notifyListeners();
        }
      });
      
      return (true, null);
    } catch (e) {
      print('退出登录失败: $e');
      
      _syncMessage = '退出登录失败: ${e.toString().split('\n')[0]}';
      notifyListeners();
      
      // 延迟一点时间再清除同步状态
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          _setLoading(false);
          notifyListeners();
        }
      });
      
      return (false, "退出登录失败: $e");
    } finally {
      if (!force) {
        _setLoading(false);
      }
    }
  }

  // 仅获取服务器数据
  Future<bool> fetchServerDataOnly() async {
    print('AppProvider: 仅获取服务器数据');
    try {
      // 获取服务器数据
      await fetchNotesFromServer();
      return true;
    } catch (e) {
      print('AppProvider: 获取服务器数据失败: $e');
      return false;
    }
  }

  // 创建笔记
  Future<Note> createNote(String content) async {
    print('AppProvider: 开始创建笔记');
    try {
      // 提取标签
      final tags = extractTags(content);
      print('AppProvider: 提取标签: $tags');
      
      // 当前时间
      final now = DateTime.now();
      
      // 创建笔记对象
      final note = Note(
        id: const Uuid().v4(),
        content: content,
        tags: tags,
        createdAt: now,
        updatedAt: now,
        isSynced: false, // 默认未同步
      );
      
      // 如果是在线模式且已登录，先尝试保存到服务器
      if (!_appConfig.isLocalMode && isLoggedIn && _memosApiService != null) {
        print('AppProvider: 尝试保存到服务器');
        try {
          final serverNote = await _memosApiService!.createMemo(
            content: content,
            visibility: _appConfig.defaultNoteVisibility,
          );
          
          // 确保服务器返回的笔记标记为已同步
          final syncedServerNote = serverNote.copyWith(isSynced: true);
          
          // 保存到本地
          await _databaseService.saveNote(syncedServerNote);
          
          // 添加到内存列表
          _notes.insert(0, syncedServerNote); // 添加到列表顶部而不是末尾
          
          print('AppProvider: 笔记已保存到服务器和本地');
          
          // 处理引用关系
          await _processNoteReferences(syncedServerNote);
          
          // 应用当前排序
          _applyCurrentSort();
          notifyListeners();
          
          return syncedServerNote;
        } catch (e) {
          print('AppProvider: 保存到服务器失败: $e');
          
          // 检查是否为Token过期异常
          if (e is TokenExpiredException || 
              e.toString().contains('Token无效或已过期')) {
            print('AppProvider: 检测到Token过期，强制用户重新登录');
            await _handleTokenExpired();
            throw Exception('登录已过期，请重新登录');
          } else {
            print('AppProvider: 将改为本地保存');
            
            // 服务器保存失败，尝试重新初始化API服务
            if (_appConfig.memosApiUrl != null && _user?.token != null) {
              _initializeApiService(_appConfig.memosApiUrl!, _user!.token!).then((_) {
                // API服务重新初始化后，尝试同步未同步的笔记
                syncNotesWithServer();
              });
            }
            
            // 继续本地保存流程
          }
        }
      }
      
      // 本地模式或服务器保存失败，保存到本地
      print('AppProvider: 本地保存');
      await _databaseService.saveNote(note);
      
      // 添加到内存列表
      _notes.insert(0, note); // 添加到列表顶部而不是末尾
      
      // 确保置顶笔记仍在最前面
      _applyCurrentSort();
      
      print('AppProvider: 本地保存成功');
      notifyListeners();
      return note;
    } catch (e) {
      print('AppProvider: 创建笔记失败: $e');
      throw Exception('创建笔记失败: $e');
    }
  }
  
  // 应用当前排序规则
  void _applyCurrentSort() {
    final currentOrder = _getCurrentSortOrder();
    sortNotes(currentOrder);
  }

  // 更新笔记
  Future<bool> updateNote(Note note, String newContent) async {
    print('AppProvider: 开始更新笔记 ID: ${note.id}');
    try {
      // 更新内容
      print('AppProvider: 创建更新后的笔记对象');
      final updatedNote = note.copyWith(
        content: newContent,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      
      // 提取标签
      print('AppProvider: 提取标签');
      final tags = extractTags(newContent);
      print('AppProvider: 提取到的标签: ${tags.join(', ')}');
      final noteWithTags = updatedNote.copyWith(tags: tags);
      
      // 更新本地数据库
      print('AppProvider: 更新本地数据库');
      await _databaseService.updateNote(noteWithTags);
      
      // 如果是在线模式且已登录，尝试同步到服务器
      if (!_appConfig.isLocalMode && isLoggedIn && _memosApiService != null) {
        try {
          print('AppProvider: 尝试同步到服务器，笔记ID: ${noteWithTags.id}');
          // 使用Memos API更新笔记
          final serverNote = await _memosApiService!.updateMemo(
            noteWithTags.id,
            content: newContent,
          );
          
          // 检查返回的笔记ID是否与原笔记ID不同
          if (serverNote.id != noteWithTags.id) {
            print('AppProvider: 服务器返回了新的笔记ID: ${serverNote.id}，原ID: ${noteWithTags.id}');
            // 删除本地旧笔记
            await _databaseService.deleteNote(noteWithTags.id);
            
            // 保存新笔记
            final newSyncedNote = serverNote.copyWith(isSynced: true, tags: tags);
            await _databaseService.saveNote(newSyncedNote);
            
            // 更新内存中的列表 - 删除旧笔记
            _notes.removeWhere((n) => n.id == noteWithTags.id);
            // 添加新笔记
            _notes.insert(0, newSyncedNote); // 添加到列表顶部
            
            _applyCurrentSort();
            notifyListeners();
            print('AppProvider: 笔记已作为新笔记保存（ID已更改）');
            return true;
          }
          
          print('AppProvider: 服务器同步成功，更新同步状态');
          
          // 🔧 重要修复：保护本地引用关系数据
          // 获取当前内存中的笔记（包含本地引用关系）
          final index = _notes.indexWhere((n) => n.id == note.id);
          List<Map<String, dynamic>> existingRelations = [];
          if (index != -1) {
            existingRelations = _notes[index].relations;
          }
          
          // 创建同步后的笔记，保留本地引用关系
          final syncedNote = serverNote.copyWith(
            isSynced: true, 
            tags: tags,
            relations: existingRelations, // 🔧 保护本地引用关系
          );
          await _databaseService.updateNote(syncedNote);
          
          // 更新内存中的列表
          if (index != -1) {
            print('AppProvider: 更新内存中的笔记（保留本地引用关系）');
            _notes[index] = syncedNote;
          }
          
          // 处理引用关系
          await _processNoteReferences(syncedNote);
          
          // 应用当前排序并通知UI更新
          _applyCurrentSort();
          notifyListeners();
          
          print('AppProvider: 笔记更新完成（已同步到服务器）');
          return true;
        } catch (e) {
          print('AppProvider: 同步到服务器失败: $e');
          // 如果同步失败，保持本地更新
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = noteWithTags;
          }
          
          // 即使服务器同步失败，也要处理引用关系
          await _processNoteReferences(noteWithTags);
          
          _applyCurrentSort();
          notifyListeners();
          print('AppProvider: 笔记更新完成（仅本地更新）');
          return true;
        }
      } else {
        // 本地模式直接更新内存中的列表
        print('AppProvider: 本地模式更新');
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = noteWithTags;
        }
        
        // 本地模式也要处理引用关系
        await _processNoteReferences(noteWithTags);
        
        _applyCurrentSort();
        notifyListeners();
        print('AppProvider: 笔记本地更新完成');
        return true;
      }
    } catch (e) {
      print('AppProvider: 更新笔记失败: $e');
      return false;
    }
  }

  // 删除笔记（本地和服务器）
  Future<bool> deleteNote(String id) async {
    print('AppProvider: 开始删除笔记 ID: $id');
    try {
      // 如果是在线模式且已登录，先尝试从服务器删除
      if (!_appConfig.isLocalMode && isLoggedIn && _memosApiService != null) {
        try {
          print('AppProvider: 尝试从服务器删除');
          await deleteNoteFromServer(id);
        } catch (e) {
          print('AppProvider: 从服务器删除笔记失败: $e');
          // 如果是404错误（笔记不存在），继续删除本地笔记
          if (!e.toString().contains('404')) {
            throw e;
          }
        }
      }
      
      // 删除本地数据库中的笔记
      print('AppProvider: 删除本地笔记');
      await deleteNoteLocal(id);
      
      print('AppProvider: 笔记删除完成');
      return true;
    } catch (e) {
      print('AppProvider: 删除笔记失败: $e');
      return false;
    }
  }

  // 仅从本地数据库删除笔记
  Future<bool> deleteNoteLocal(String id) async {
    print('AppProvider: 从本地数据库删除笔记 ID: $id');
    try {
      // 删除本地数据库中的笔记
      await _databaseService.deleteNote(id);
      
      // 从内存中的列表删除
      _notes.removeWhere((note) => note.id == id);
      
      // 🔧 新增：立即清理所有相关的引用关系
      await _cleanupReferencesForDeletedNote(id);
      
      notifyListeners();
      
      print('AppProvider: 本地笔记删除成功');
      return true;
    } catch (e) {
      print('AppProvider: 从本地删除笔记失败: $e');
      throw Exception('删除本地笔记失败: $e');
    }
  }

  /// 🔧 新增：清理被删除笔记的所有相关引用关系
  Future<void> _cleanupReferencesForDeletedNote(String deletedNoteId) async {
    try {
      if (kDebugMode) {
        print('AppProvider: 清理删除笔记 $deletedNoteId 的相关引用关系');
      }
      
      bool hasChanges = false;
      
      // 遍历所有剩余笔记，清理指向被删除笔记的引用关系
      for (int i = 0; i < _notes.length; i++) {
        final note = _notes[i];
        final originalRelationsCount = note.relations.length;
        
        // 过滤掉所有与被删除笔记相关的引用关系
        final cleanedRelations = note.relations.where((relation) {
          final memoId = relation['memoId']?.toString();
          final relatedMemoId = relation['relatedMemoId']?.toString();
          
          // 删除所有涉及被删除笔记的关系
          return memoId != deletedNoteId && relatedMemoId != deletedNoteId;
        }).toList();
        
        if (cleanedRelations.length != originalRelationsCount) {
          final updatedNote = note.copyWith(relations: cleanedRelations);
          await _databaseService.updateNote(updatedNote);
          _notes[i] = updatedNote;
          hasChanges = true;
          
          final removedCount = originalRelationsCount - cleanedRelations.length;
          if (kDebugMode) {
            print('AppProvider: 从笔记 ${note.id} 清理了 $removedCount 个相关引用关系');
          }
        }
      }
      
      if (hasChanges) {
        if (kDebugMode) {
          print('AppProvider: ✅ 删除笔记相关引用关系清理完成');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 清理删除笔记引用关系失败: $e');
      }
    }
  }

  // 仅从服务器删除笔记
  Future<bool> deleteNoteFromServer(String id) async {
    print('AppProvider: 从服务器删除笔记 ID: $id');
    try {
      if (!isLoggedIn || _memosApiService == null) {
        print('AppProvider: 未登录或API服务不可用');
        return false;
      }
      
      // 从服务器删除
      await _memosApiService!.deleteMemo(id);
      print('AppProvider: 服务器笔记删除成功');
      return true;
    } catch (e) {
      print('AppProvider: 从服务器删除笔记失败: $e');
      throw Exception('从服务器删除笔记失败: $e');
    }
  }

  // 手动刷新数据（从服务器获取最新数据）
  Future<void> refreshFromServer() async {
    await fetchNotesFromServer();
  }
  
  /// 🚀 优化版：增量刷新数据
  /// 只同步变化的数据，速度快10倍以上
  Future<void> refreshFromServerFast() async {
    if (!isLoggedIn || _memosApiService == null) {
      throw Exception('用户未登录');
    }
    
    if (_incrementalSyncService == null) {
      // 如果增量同步服务未初始化，使用传统方式
      print('AppProvider: 增量同步服务未初始化，使用传统同步');
      await fetchNotesFromServer();
      return;
    }
    
    _isSyncing = true;
    _syncMessage = '智能同步中...';
    notifyListeners();
    
    try {
      final startTime = DateTime.now();
      
      // 1. 先显示本地数据（无需等待，立即响应）
      if (_notes.isEmpty) {
        _notes = await _databaseService.getNotes();
        notifyListeners();
        print('AppProvider: 已加载本地数据 ${_notes.length} 条');
      }
      
      // 2. 后台增量同步
      _syncMessage = '检查更新...';
      notifyListeners();
      
      final syncResult = await _incrementalSyncService!.incrementalSync();
      
      // 3. 更新内存中的数据
      _notes = await _databaseService.getNotes();
      
      final duration = DateTime.now().difference(startTime);
      _syncMessage = '同步完成 (${duration.inMilliseconds}ms)';
      
      print('AppProvider: ✅ 增量同步完成');
      print('AppProvider: ${syncResult.toString()}');
      
      notifyListeners();
      
      // 4. 在后台处理引用关系（不阻塞UI）
      if (syncResult.newNotes > 0 || syncResult.updatedNotes > 0) {
        _rebuildReferencesInBackground();
      }
      
    } catch (e) {
      print('AppProvider: 增量同步失败: $e');
      _syncMessage = '同步失败: ${e.toString().split('\n')[0]}';
      notifyListeners();
      rethrow;
    } finally {
      // 延迟清除同步状态
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          notifyListeners();
        }
      });
    }
  }
  
  /// 后台重建引用关系（不阻塞UI）
  Future<void> _rebuildReferencesInBackground() async {
    try {
      // 🚀 后台重建（静默）
      await rebuildAllReferences();
      if (kDebugMode) print('AppProvider: 后台引用关系重建完成');
    } catch (e) {
      if (kDebugMode) print('AppProvider: 后台重建失败: $e');
    }
  }

  // 完整的数据同步（用户手动刷新时调用）
  Future<void> performCompleteSync() async {
    try {
      if (!isLoggedIn || _memosApiService == null) {
        throw Exception('用户未登录或API服务未初始化');
      }
      
      _syncMessage = '开始完整同步...';
      notifyListeners();
      
      if (kDebugMode) {
        print('AppProvider: ========== 开始完整同步 ==========');
      }
      
      // 1. 获取所有本地数据
      _syncMessage = '分析本地数据...';
      notifyListeners();
      
      final localNotes = await _databaseService.getNotes();
      final unsyncedNotes = localNotes.where((note) => !note.isSynced).toList();
      final unsyncedRelations = await _getUnsyncedRelations();
      
      if (kDebugMode) {
        print('AppProvider: 本地笔记总数: ${localNotes.length}');
        print('AppProvider: 未同步笔记: ${unsyncedNotes.length}');
        print('AppProvider: 未同步引用关系: ${unsyncedRelations.length}');
      }
      
      // 2. 上传未同步的本地笔记
      if (unsyncedNotes.isNotEmpty) {
        _syncMessage = '上传本地笔记 (${unsyncedNotes.length}条)...';
        notifyListeners();
        
        for (var note in unsyncedNotes) {
          try {
            await _uploadLocalNoteToServer(note);
            if (kDebugMode) {
              print('AppProvider: 成功上传笔记 ${note.id}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('AppProvider: 上传笔记 ${note.id} 失败: $e');
            }
          }
        }
      }
      
      // 3. 获取服务器数据并合并
      _syncMessage = '获取服务器数据...';
      notifyListeners();
      
      await fetchNotesFromServer();
      
      // 4. 重新处理所有引用关系
      _syncMessage = '同步引用关系...';
      notifyListeners();
      
      await _syncAllNotesReferences();
      
      // 5. 清理无效的引用关系
      _syncMessage = '清理无效数据...';
      notifyListeners();
      
      await _cleanupInvalidReferences();
      
      // 6. 清理所有孤立的引用关系
      _syncMessage = '清理孤立引用关系...';
      notifyListeners();
      
      await _cleanupAllOrphanedReferences();
      
      // 🔧 新增：使用UnifiedReferenceManager进行额外的无效引用清理
      await UnifiedReferenceManager().cleanupInvalidReferences();
      
      _syncMessage = '';
      notifyListeners();
      
      if (kDebugMode) {
        print('AppProvider: ========== 完整同步完成 ==========');
      }
      
    } catch (e) {
      _syncMessage = '';
      notifyListeners();
      if (kDebugMode) {
        print('AppProvider: 完整同步失败: $e');
      }
      throw Exception('同步失败: $e');
    }
  }

  // 上传单个本地笔记到服务器
  Future<void> _uploadLocalNoteToServer(Note note) async {
    try {
      final serverNote = await _memosApiService!.createMemo(
        content: note.content,
        visibility: note.visibility,
      );
      
      // 如果服务器返回了不同的ID，需要更新本地记录
      if (serverNote.id != note.id) {
        // 删除旧的本地记录
        await _databaseService.deleteNote(note.id);
        
        // 保存新的记录
        final syncedNote = serverNote.copyWith(
          isSynced: true,
          tags: note.tags,
          relations: note.relations,
        );
        await _databaseService.saveNote(syncedNote);
        
        // 更新内存中的笔记列表
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = syncedNote;
        }
        
        if (kDebugMode) {
          print('AppProvider: 笔记ID已更新: ${note.id} -> ${serverNote.id}');
        }
      } else {
        // ID相同，只需要标记为已同步
        final syncedNote = note.copyWith(isSynced: true);
        await _databaseService.updateNote(syncedNote);
        
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = syncedNote;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 上传笔记失败: $e');
      }
      rethrow;
    }
  }

  // 获取所有未同步的引用关系
  Future<List<Map<String, dynamic>>> _getUnsyncedRelations() async {
    final unsyncedRelations = <Map<String, dynamic>>[];
    
    for (var note in _notes) {
      for (var relation in note.relations) {
        if (relation['synced'] == false) {
          unsyncedRelations.add({
            ...relation,
            'noteId': note.id,
          });
        }
      }
    }
    
    return unsyncedRelations;
  }

  // 同步所有笔记的引用关系
  Future<void> _syncAllNotesReferences() async {
    try {
      for (var note in _notes) {
        await _processNoteReferences(note);
        // 添加小延迟避免请求过于频繁
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (kDebugMode) {
        print('AppProvider: 所有笔记引用关系同步完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 同步引用关系失败: $e');
      }
    }
  }

  // 清理所有笔记的孤立引用关系
  Future<void> _cleanupAllOrphanedReferences() async {
    try {
      if (kDebugMode) {
        print('AppProvider: 开始清理所有孤立的引用关系');
      }
      
      int totalCleaned = 0;
      
      // 遍历所有笔记
      for (int i = 0; i < _notes.length; i++) {
        final note = _notes[i];
        
        // 查找孤立的REFERENCED_BY关系
        final orphanedReverseRelations = note.relations.where((rel) {
          final type = rel['type'];
          final fromMemoId = rel['memoId']?.toString();
          
          // 如果是REFERENCED_BY类型，检查源笔记是否还存在对应的REFERENCE关系
          if (type == 'REFERENCED_BY' && fromMemoId != null && fromMemoId != note.id) {
            final sourceNoteIndex = _notes.indexWhere((n) => n.id == fromMemoId);
            if (sourceNoteIndex != -1) {
              final sourceNote = _notes[sourceNoteIndex];
              
              // 检查源笔记是否还有对当前笔记的引用关系
              final hasCorrespondingReference = sourceNote.relations.any((sourceRel) =>
                sourceRel['type'] == 'REFERENCE' &&
                sourceRel['memoId']?.toString() == fromMemoId &&
                sourceRel['relatedMemoId']?.toString() == note.id
              );
              
              if (!hasCorrespondingReference) {
                if (kDebugMode) {
                  print('AppProvider: 发现孤立的REFERENCED_BY关系: $fromMemoId -> ${note.id}');
                }
                return true; // 这是一个孤立的关系，需要删除
              }
            } else {
              // 源笔记不存在，也是孤立关系
              if (kDebugMode) {
                print('AppProvider: 发现指向不存在笔记的REFERENCED_BY关系: $fromMemoId -> ${note.id}');
              }
              return true;
            }
          }
          return false;
        }).toList();
        
        // 删除孤立的REFERENCED_BY关系
        if (orphanedReverseRelations.isNotEmpty) {
          final cleanedRelations = note.relations.where((rel) => !orphanedReverseRelations.contains(rel)).toList();
          final cleanedNote = note.copyWith(relations: cleanedRelations);
          await _databaseService.updateNote(cleanedNote);
          
          _notes[i] = cleanedNote;
          totalCleaned += orphanedReverseRelations.length;
          
          if (kDebugMode) {
            print('AppProvider: ✅ 从笔记 ${note.id} 清理了 ${orphanedReverseRelations.length} 个孤立的REFERENCED_BY关系');
          }
        }
      }
      
      if (totalCleaned > 0) {
        notifyListeners(); // 更新UI
        if (kDebugMode) {
          print('AppProvider: 孤立引用关系清理完成，总共清理了 $totalCleaned 个关系');
        }
      } else {
        if (kDebugMode) {
          print('AppProvider: 没有发现孤立的引用关系');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 清理孤立引用关系失败: $e');
      }
    }
  }

  // 清理无效的引用关系
  Future<void> _cleanupInvalidReferences() async {
    try {
      final allNotes = await _databaseService.getNotes();
      final noteIds = allNotes.map((n) => n.id).toSet();
      
      for (var note in allNotes) {
        bool hasInvalidReferences = false;
        final validRelations = <Map<String, dynamic>>[];
        
        for (var relation in note.relations) {
          final relatedId = relation['relatedMemoId']?.toString();
          if (relatedId != null && noteIds.contains(relatedId)) {
            validRelations.add(relation);
          } else {
            hasInvalidReferences = true;
            if (kDebugMode) {
              print('AppProvider: 清理笔记 ${note.id} 的无效引用关系: $relatedId');
            }
          }
        }
        
        if (hasInvalidReferences) {
          final updatedNote = note.copyWith(relations: validRelations);
          await _databaseService.updateNote(updatedNote);
          
          // 更新内存中的笔记
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = updatedNote;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 清理无效引用关系失败: $e');
      }
    }
  }

  /// 🔧 新增：在笔记ID变化后更新所有引用关系
  Future<void> _updateReferenceIdsAfterSync(String oldId, String newId) async {
    try {
      if (kDebugMode) {
        print('AppProvider: 更新引用关系ID: $oldId -> $newId');
      }
      
      final allNotes = await _databaseService.getNotes();
      bool hasUpdates = false;
      
      for (var note in allNotes) {
        bool noteUpdated = false;
        final updatedRelations = <Map<String, dynamic>>[];
        
        for (var relation in note.relations) {
          final relationMap = Map<String, dynamic>.from(relation);
          
          // 更新 memoId
          if (relationMap['memoId'] == oldId) {
            relationMap['memoId'] = newId;
            noteUpdated = true;
          }
          
          // 更新 relatedMemoId
          if (relationMap['relatedMemoId'] == oldId) {
            relationMap['relatedMemoId'] = newId;
            noteUpdated = true;
          }
          
          updatedRelations.add(relationMap);
        }
        
        if (noteUpdated) {
          final updatedNote = note.copyWith(relations: updatedRelations);
          await _databaseService.updateNote(updatedNote);
          hasUpdates = true;
          
          if (kDebugMode) {
            print('AppProvider: 更新笔记 ${note.id} 的引用关系');
          }
        }
      }
      
      if (hasUpdates) {
        // 重新加载内存中的笔记
        await loadNotesFromLocal();
        notifyListeners();
        
        if (kDebugMode) {
          print('AppProvider: 引用关系ID更新完成');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 更新引用关系ID失败: $e');
      }
    }
  }

  // 从服务器获取笔记
  Future<void> fetchNotesFromServer() async {
    // 设置同步状态
    _isSyncing = true;
    _syncMessage = '正在从服务器获取数据...';
    notifyListeners();
    
    try {
      // 检查并快速重新初始化API服务
      if (_memosApiService == null) {
        await _ensureApiServiceInitialized();
      }
      
      // 首先获取本地所有笔记（包括已同步和未同步的）
      _syncMessage = '备份本地笔记...';
      notifyListeners();
      
      print('AppProvider: 获取所有本地笔记');
      final localNotes = await _databaseService.getNotes();
      final unsyncedNotes = await _databaseService.getUnsyncedNotes();
      print('AppProvider: 本地共有 ${localNotes.length} 条笔记，其中 ${unsyncedNotes.length} 条未同步');
      
      _syncMessage = '获取远程笔记...';
      notifyListeners();
      
      print('AppProvider: 从服务器获取笔记');
      final response = await _memosApiService!.getMemos();
      if (response == null) {
        throw Exception('服务器返回数据为空');
      }
      
      _syncMessage = '处理笔记数据...';
      notifyListeners();
      
      final memosList = response['memos'] as List<dynamic>;
      final serverNotes = memosList.map((memo) => Note.fromJson(memo as Map<String, dynamic>)).toList();
      
      // 🚀 性能优化：批量处理标签提取，不阻塞UI
      // Note.fromJson已经包含relationList，无需单独请求引用关系
      for (var i = 0; i < serverNotes.length; i++) {
        var note = serverNotes[i];
        var tags = Note.extractTagsFromContent(note.content);
        
        // 确保服务器笔记都标记为已同步，relations已在fromJson中处理
        serverNotes[i] = note.copyWith(
          tags: tags, 
          isSynced: true,
        );
      }
      
      if (kDebugMode) {
        print('AppProvider: 已处理 ${serverNotes.length} 条笔记的标签提取');
      }
      
      _syncMessage = '智能合并数据...';
      notifyListeners();
      
      // 智能合并策略：优先保留服务器数据，但不丢失本地未同步的数据
      final mergedNotes = <Note>[];
      final serverNoteIds = serverNotes.map((note) => note.id).toSet();
      final serverNoteHashes = serverNotes.map(_calculateNoteHash).toSet();
      
      // 1. 添加所有服务器笔记，但保留本地的引用关系
      for (var serverNote in serverNotes) {
        // 查找对应的本地笔记，获取其引用关系
        final localNote = localNotes.firstWhere(
          (note) => note.id == serverNote.id,
          orElse: () => Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );
        
        // 如果本地笔记存在且有引用关系，合并引用关系
        if (localNote.id.isNotEmpty && localNote.relations.isNotEmpty) {
          // 合并引用关系：优先保留本地的relations
          final mergedNote = serverNote.copyWith(relations: localNote.relations);
          mergedNotes.add(mergedNote);
          if (kDebugMode) {
            print('AppProvider: 服务器笔记 ${serverNote.id} 合并了 ${localNote.relations.length} 个本地引用关系');
          }
        } else {
          mergedNotes.add(serverNote);
        }
      }
      print('AppProvider: 添加 ${serverNotes.length} 条服务器笔记');
      
      // 2. 添加本地未同步的笔记（避免重复）
      int addedUnsyncedCount = 0;
      for (var note in unsyncedNotes) {
        final noteHash = _calculateNoteHash(note);
        
        // 检查是否与服务器数据重复
        bool isDuplicate = serverNoteHashes.contains(noteHash);
        bool hasIdConflict = serverNoteIds.contains(note.id) && !note.id.startsWith('local_');
        
        if (!isDuplicate) {
          // 如果ID冲突但内容不重复，生成新的本地ID
          if (hasIdConflict) {
            note = note.copyWith(
              id: 'local_${DateTime.now().millisecondsSinceEpoch}_${addedUnsyncedCount}',
              isSynced: false,
            );
          }
          mergedNotes.add(note);
          addedUnsyncedCount++;
        } else {
          print('AppProvider: 跳过重复笔记: ${note.id}');
        }
      }
      
      print('AppProvider: 添加 $addedUnsyncedCount 条本地未同步笔记');
      
      // 3. 更新本地数据库
      print('AppProvider: 更新本地数据库');
      await _databaseService.clearAllNotes();
      await _databaseService.saveNotes(mergedNotes);
      
      // 4. 更新内存中的列表
      _notes = await _databaseService.getNotes();
      
      _syncMessage = '同步完成';
      notifyListeners();
      
      print('AppProvider: 笔记同步完成，共 ${_notes.length} 条笔记');
    } catch (e, stackTrace) {
      print('AppProvider: 从服务器获取数据失败: $e');
      print('AppProvider: 错误堆栈: $stackTrace');
      
      // 检查是否为Token过期异常
      if (e is TokenExpiredException || 
          e.toString().contains('Token无效或已过期')) {
        print('AppProvider: 检测到Token过期，强制用户重新登录');
        _syncMessage = '登录已过期，请重新登录';
        notifyListeners();
        await _handleTokenExpired();
        return;
      }
      
      _syncMessage = '同步失败: ${e.toString().split('\n')[0]}';
      notifyListeners();
      
      // 如果是API服务初始化失败，尝试清除登录状态
      if (e.toString().contains('API服务初始化失败')) {
        await logout(force: true);
      }
      
      print('AppProvider: 保留本地数据');
      // 加载本地数据作为后备
      await loadNotesFromLocal();
      
      rethrow;
    } finally {
      // 延迟一点时间再清除同步状态，让用户有时间看到"同步完成"
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          notifyListeners();
        }
      });
    }
  }

  // 同步本地未同步的笔记到服务器
  Future<void> syncNotesWithServer() async {
    if (!isLoggedIn || _memosApiService == null) return;
    
    try {
      // 获取未同步的笔记
      final unsyncedNotes = await _databaseService.getUnsyncedNotes();
      
      if (unsyncedNotes.isEmpty) return;
      
      // 逐一同步到服务器
      for (var note in unsyncedNotes) {
        try {
          final oldId = note.id;
          
          // 创建服务器笔记
          final serverNote = await _memosApiService!.createMemo(
            content: note.content,
            visibility: note.visibility.isNotEmpty ? note.visibility : _appConfig.defaultNoteVisibility,
          );
          
          final newId = serverNote.id;
          
          // 🔧 修复：如果ID发生变化，更新所有引用关系
          if (oldId != newId) {
            await _updateReferenceIdsAfterSync(oldId, newId);
          }
          
          // 删除本地笔记（使用临时ID）
          await _databaseService.deleteNote(note.id);
          
          // 保存服务器返回的笔记（带有服务器ID）
          await _databaseService.saveNote(serverNote);
          
          // 更新内存中的列表
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = serverNote;
          }
        } catch (e) {
          print('同步笔记失败: ${note.id} - $e');
        }
      }
      
      // 刷新内存中的列表
      await loadNotesFromLocal();
    } catch (e) {
      print('同步笔记到服务器失败: $e');
    }
  }

  // 创建同步定时器
  void _createSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _appConfig.syncInterval),
      (_) => syncNotesToServer(),
    );
  }

  // 同步笔记到服务器
  Future<bool> syncNotesToServer() async {
    if (!isLoggedIn || _memosApiService == null) return false;
    
    try {
      // 获取未同步的笔记
      final unsyncedNotes = await _databaseService.getUnsyncedNotes();
      
      // 逐一同步到服务器
      for (var note in unsyncedNotes) {
        try {
          final oldId = note.id;
          
          // 创建服务器笔记
          final serverNote = await _memosApiService!.createMemo(
            content: note.content,
            visibility: note.visibility.isNotEmpty ? note.visibility : _appConfig.defaultNoteVisibility,
          );
          
          final newId = serverNote.id;
          
          // 🔧 修复：如果ID发生变化，更新所有引用关系
          if (oldId != newId) {
            await _updateReferenceIdsAfterSync(oldId, newId);
          }
          
          // 删除本地笔记（使用临时ID）
          await _databaseService.deleteNote(note.id);
          
          // 保存服务器返回的笔记（带有服务器ID）
          await _databaseService.saveNote(serverNote);
          
          // 更新内存中的列表
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = serverNote;
          }
        } catch (e) {
          print('同步笔记失败: ${note.id} - $e');
        }
      }
      
      // 刷新内存中的列表
      await loadNotesFromLocal();
      return true;
    } catch (e) {
      print('同步笔记到服务器失败: $e');
      return false;
    }
  }

  // 更新用户信息到服务器
  Future<bool> updateUserInfo({
    String? nickname,
    String? email,
    String? avatarUrl,
    String? description,
  }) async {
    if (!isLoggedIn || _memosApiService == null || _user == null) return false;
    
    _setLoading(true);
    
    try {
      // 使用Memos API更新用户信息
      final updatedUser = await _memosApiService!.updateUserInfo(
        nickname: nickname,
        email: email,
        avatarUrl: avatarUrl,
        description: description,
      );

      // 更新本地用户信息
      _user = updatedUser;
      await _preferencesService.saveUser(_user!);

      notifyListeners();
      return true;
    } catch (e) {
      print('更新用户信息失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // 保存登录信息
  Future<void> saveLoginInfo(String server, String usernameOrToken, {String? token, String? password}) async {
    print('AppProvider: 保存登录信息 - 服务器: $server');
    // 规范化URL（确保末尾没有斜杠）
    final normalizedUrl = server.endsWith('/')
        ? server.substring(0, server.length - 1)
        : server;
        
    // 生成一个刷新令牌（这里只是为了满足接口要求）
    final refreshToken = const Uuid().v4();
    
    // 如果提供了token参数，则usernameOrToken是用户名，否则是token（兼容旧版本）
    if (token != null) {
      // 新版本：保存用户名和token
      await _preferencesService.saveLoginInfo(
        token: token,
        refreshToken: refreshToken,
        serverUrl: normalizedUrl,
        username: usernameOrToken, // 这里是用户名
        password: password, // 保存密码（如果提供）
      );
      
      // 同时更新AppConfig
      final updatedConfig = _appConfig.copyWith(
        memosApiUrl: normalizedUrl,
        lastToken: token,
        lastUsername: usernameOrToken,
        lastServerUrl: normalizedUrl,
        rememberLogin: true,
      );
      await updateConfig(updatedConfig);
    } else {
      // 旧版本：usernameOrToken是token
      await _preferencesService.saveLoginInfo(
        token: usernameOrToken,
        refreshToken: refreshToken,
        serverUrl: normalizedUrl,
      );
      
      // 同时更新AppConfig
      final updatedConfig = _appConfig.copyWith(
        memosApiUrl: normalizedUrl,
        lastToken: usernameOrToken,
        lastServerUrl: normalizedUrl,
        rememberLogin: true,
      );
      await updateConfig(updatedConfig);
    }
    
    print('AppProvider: 登录信息保存成功');
  }

  // 清除登录信息
  Future<void> clearLoginInfo() async {
    await _preferencesService.clearLoginInfo();
  }

  // 获取保存的服务器地址
  Future<String?> getSavedServer() async {
    return await _preferencesService.getSavedServer();
  }

  // 获取保存的Token
  Future<String?> getSavedToken() async {
    return await _preferencesService.getSavedToken();
  }

  // 获取保存的用户名
  Future<String?> getSavedUsername() async {
    return await _preferencesService.getSavedUsername();
  }

  // 获取保存的密码
  Future<String?> getSavedPassword() async {
    return await _preferencesService.getSavedPassword();
  }

  // 启动自动同步
  void startAutoSync() {
    stopAutoSync();
    if (!_appConfig.isLocalMode && _memosApiService != null) {
      _syncTimer = Timer.periodic(Duration(minutes: 5), (_) {
        syncLocalDataToServer();
      });
      print('AppProvider: 自动同步已启动');
    } else {
      print('AppProvider: 本地模式或API服务未初始化，不启动自动同步');
    }
  }

  // 停止自动同步
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('AppProvider: 自动同步已停止');
  }

  // 初始化API服务
  Future<void> _initializeApiService(String baseUrl, String token) async {
    try {
      print('AppProvider: 开始初始化API服务，URL：$baseUrl');
      final normalizedUrl = ApiServiceFactory.normalizeApiUrl(baseUrl);
      print('AppProvider: 规范化后的URL: $normalizedUrl');
      
      _memosApiService = await ApiServiceFactory.createApiService(
        baseUrl: normalizedUrl,
        token: token,
      ) as MemosApiServiceFixed;
      
      // 验证API服务是否正常工作
      final testResponse = await _memosApiService!.getMemos();
      if (testResponse != null) {
        print('AppProvider: API服务初始化成功，验证通过');
        
        // 初始化增量同步服务
        _incrementalSyncService = IncrementalSyncService(_databaseService, _memosApiService);
        print('AppProvider: 增量同步服务已初始化');
        
        // 更新配置
        final updatedConfig = _appConfig.copyWith(
          memosApiUrl: normalizedUrl,
          lastToken: token,
          isLocalMode: false,
        );
        await updateConfig(updatedConfig);
        
        // 启动自动同步
        startAutoSync();
      } else {
        print('AppProvider: API服务初始化成功，但验证失败');
        _memosApiService = null;
        // 清除保存的凭证
        await _preferencesService.clearLoginInfo();
      }
    } catch (e) {
      print('AppProvider: API服务初始化失败: $e');
      _memosApiService = null;
      // 清除保存的凭证
      await _preferencesService.clearLoginInfo();
      rethrow;
    }
  }

  // 从云端同步数据
  Future<void> syncWithServer() async {
    if (!isLoggedIn || _memosApiService == null) {
              throw Exception('请先登录您的账号');
    }
    
    // 设置同步状态
    _isSyncing = true;
    _syncMessage = '准备同步...';
    notifyListeners();
    
    try {
      // 1. 先将本地未同步的笔记上传到服务器
      _syncMessage = '上传本地笔记...';
      notifyListeners();
      
      final unsyncedNotes = await _databaseService.getUnsyncedNotes();
      print('AppProvider: 发现 ${unsyncedNotes.length} 条未同步笔记');
      
      for (var note in unsyncedNotes) {
        try {
          final oldId = note.id;
          
          // 创建服务器笔记
          final serverNote = await _memosApiService!.createMemo(
            content: note.content,
            visibility: note.visibility.isNotEmpty ? note.visibility : _appConfig.defaultNoteVisibility,
          );
          
          final newId = serverNote.id;
          
          // 🔧 修复：如果ID发生变化，更新所有引用关系
          if (oldId != newId) {
            await _updateReferenceIdsAfterSync(oldId, newId);
          }
          
          // 删除本地笔记（使用临时ID）
          await _databaseService.deleteNote(note.id);
          
          // 保存服务器返回的笔记（带有服务器ID）
          await _databaseService.saveNote(serverNote);
          
          // 更新内存中的列表
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = serverNote;
          }
        } catch (e) {
          print('同步笔记到服务器失败: ${note.id} - $e');
        }
      }
      
      // 2. 从服务器获取最新数据
      _syncMessage = '获取服务器数据...';
      notifyListeners();
      
      final response = await _memosApiService!.getMemos();
      if (response == null) {
        throw Exception('服务器返回数据为空');
      }
      
      final memosList = response['memos'] as List<dynamic>;
      final serverNotes = memosList.map((memo) => Note.fromJson(memo as Map<String, dynamic>)).toList();
      
      // 3. 为所有服务器笔记重新提取标签
      _syncMessage = '处理笔记数据...';
      notifyListeners();
      
      for (var i = 0; i < serverNotes.length; i++) {
        var note = serverNotes[i];
        var tags = Note.extractTagsFromContent(note.content);
        if (tags.isNotEmpty) {
          serverNotes[i] = note.copyWith(tags: tags);
        }
      }
      
      // 4. 更新本地数据库
      _syncMessage = '更新本地数据...';
      notifyListeners();
      
      await _databaseService.clearAllNotes();
      await _databaseService.saveNotes(serverNotes);
      
      // 5. 更新内存中的列表
      _notes = await _databaseService.getNotes();
      
      _syncMessage = '同步完成';
      notifyListeners();
      
      // 延迟一点时间再清除同步状态
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          notifyListeners();
        }
      });
    } catch (e) {
      print('同步失败: $e');
      _syncMessage = '同步失败: ${e.toString().split('\n')[0]}';
      notifyListeners();
      
      // 延迟一点时间再清除同步状态
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _isSyncing = false;
          _syncMessage = null;
          notifyListeners();
        }
      });
      
      throw e;
    }
  }

  // 初始化通知并检查更新
  Future<void> _initializeAnnouncements() async {
    try {
      // 使用云验证数据检查更新
      await checkForUpdatesOnStartup();
      
      // 🔄 使用新的状态管理机制设置通知数量
      await _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('初始化通知异常: $e');
    }
  }
  
  // 刷新未读通知数量
  Future<void> refreshUnreadAnnouncementsCount() async {
    try {
      // 刷新云验证数据
      await refreshCloudData();
      
      // 🔄 使用新的状态管理机制更新通知数量
      await _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('刷新未读通知数量异常: $e');
    }
  }
  
  // 启动时检查更新
  Future<void> checkForUpdatesOnStartup() async {
    try {
      // 使用云验证数据检查更新
      final hasUpdate = await hasCloudUpdate();
      
      if (hasUpdate && _cloudAppConfig != null) {
        final currentVersion = Config.AppConfig.appVersion;
        
        // 将云验证数据转换为 VersionInfo 格式
        _pendingVersionInfo = VersionInfo(
          versionName: _cloudAppConfig!.version,
          versionCode: _parseVersionCode(_cloudAppConfig!.version),
          minRequiredVersion: _cloudAppConfig!.version,
          downloadUrls: _cloudAppConfig!.appUpdateUrl.isNotEmpty ? {'download': _cloudAppConfig!.appUpdateUrl} : {},
          releaseNotes: _cloudAppConfig!.formattedVersionInfo,
          forceUpdate: _cloudAppConfig!.isForceUpdate,
        );
        _pendingCurrentVersion = currentVersion;
      }
    } catch (e) {
      print('启动时检查更新异常: $e');
    }
  }
  
  // 解析版本号为版本代码
  int _parseVersionCode(String version) {
    final parts = version.split('.');
    int code = 0;
    for (int i = 0; i < parts.length && i < 3; i++) {
      final part = int.tryParse(parts[i]) ?? 0;
      code += part * (1000 * (3 - i));
    }
    return code;
  }
  
  // 版本信息暂存
  VersionInfo? _pendingVersionInfo;
  String? _pendingCurrentVersion;
  
  // 显示更新对话框
  void showUpdateDialogIfNeeded(BuildContext context) {
    if (_pendingVersionInfo != null && _pendingCurrentVersion != null) {
      final versionInfo = _pendingVersionInfo!;
      final currentVersion = _pendingCurrentVersion!;
      
      // 清除暂存的版本信息
      _pendingVersionInfo = null;
      _pendingCurrentVersion = null;
      
      // 使用微任务确保对话框在下一帧显示
      Future.microtask(() {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: !versionInfo.forceUpdate,
            builder: (context) => UpdateDialog(
              versionInfo: versionInfo,
              currentVersion: currentVersion,
            ),
          );
        }
      });
    }
  }

  // 通知相关方法
  Future<void> refreshAnnouncements() async {
    await refreshCloudData();
    
    // 从云验证公告数据创建 Announcement 对象
    _announcements.clear();
    if (_cloudNotice?.appGg.isNotEmpty == true) {
      final announcement = Announcement(
        id: 'cloud_notice_${DateTime.now().millisecondsSinceEpoch}',
        title: '应用公告',
        content: _cloudNotice!.appGg,
        type: 'info',
        publishDate: DateTime.now(),
      );
      _announcements.add(announcement);
    }
    notifyListeners();
  }

  Future<void> markAnnouncementAsRead(String id) async {
    try {
      // 🔄 新实现：真正的已读状态管理
      final prefs = await SharedPreferences.getInstance();
      final readNotifications = prefs.getStringList('read_notifications') ?? [];
      
      if (!readNotifications.contains(id)) {
        readNotifications.add(id);
        await prefs.setStringList('read_notifications', readNotifications);
        if (kDebugMode) print('AppProvider: 通知 $id 已标记为已读');
      }
      
      // 重新计算未读数量
      await _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('AppProvider: 标记通知已读失败: $e');
    }
  }

  Future<void> markAllAnnouncementsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications = prefs.getStringList('read_notifications') ?? [];
      
      // 🔄 新实现：标记当前所有通知为已读
      final currentAnnouncementId = _cloudNotice?.appGg ?? '';
      if (currentAnnouncementId.isNotEmpty && !readNotifications.contains(currentAnnouncementId)) {
        readNotifications.add(currentAnnouncementId);
        await prefs.setStringList('read_notifications', readNotifications);
        if (kDebugMode) print('AppProvider: 所有通知已标记为已读');
      }
      
      await _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('AppProvider: 标记所有通知已读失败: $e');
    }
  }

  Future<bool> isAnnouncementRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications = prefs.getStringList('read_notifications') ?? [];
      return readNotifications.contains(id);
    } catch (e) {
      if (kDebugMode) print('AppProvider: 检查通知已读状态失败: $e');
      return false;
    }
  }

  // 🆕 新增：统一的未读数量更新方法
  Future<void> _updateUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications = prefs.getStringList('read_notifications') ?? [];
      
      final currentAnnouncementId = _cloudNotice?.appGg ?? '';
      
      // 🎯 关键逻辑：只有当前通知内容未被读过才显示未读数量
      if (currentAnnouncementId.isNotEmpty && 
          !readNotifications.contains(currentAnnouncementId)) {
        _unreadAnnouncementsCount = 1;
      } else {
        _unreadAnnouncementsCount = 0;
      }
      
      if (kDebugMode) print('AppProvider: 未读通知数量更新为: $_unreadAnnouncementsCount');
    } catch (e) {
      if (kDebugMode) print('AppProvider: 更新未读数量失败: $e');
      _unreadAnnouncementsCount = 0;
    }
  }

  // 🗑️ 已移除旧的通知ID管理方法，使用新的列表式状态管理

  // ===== 云验证相关方法 =====
  
  /// 加载云验证数据（配置和公告）
  Future<void> _loadCloudVerificationData() async {
    try {
      // 🚀 缓存检查：如果5分钟内已加载过，直接跳过
      if (_lastCloudVerificationTime != null) {
        final duration = DateTime.now().difference(_lastCloudVerificationTime!);
        if (duration < _cloudVerificationCacheDuration) {
          if (kDebugMode) {
            print('AppProvider: 云验证数据在缓存期内，跳过加载 (距上次${duration.inSeconds}秒)');
          }
          return;
        }
      }
      
      if (kDebugMode) print('AppProvider: 开始加载云验证数据');
      
      // 并行加载配置和公告
      final futures = await Future.wait([
        _cloudService.fetchAppConfig(),
        _cloudService.fetchAppNotice(),
      ]);
      
      final configResponse = futures[0] as CloudAppConfigResponse?;
      final noticeResponse = futures[1] as CloudNoticeResponse?;
      
      // 处理配置响应
      if (configResponse != null && configResponse.isSuccess) {
        _cloudAppConfig = configResponse.msg;
        if (kDebugMode) {
          print('AppProvider: 云配置加载成功 - 版本: ${_cloudAppConfig?.version}');
        }
        
        // 检查是否需要更新
        await _checkCloudUpdate();
      } else {
        if (kDebugMode) print('AppProvider: 云配置加载失败');
      }
      
      // 处理公告响应
      if (noticeResponse != null && noticeResponse.isSuccess) {
        _cloudNotice = noticeResponse.msg;
        // 云公告加载成功
      } else {
        // 云公告加载失败
      }
      
      // 🚀 更新缓存时间
      _lastCloudVerificationTime = DateTime.now();
      
    } catch (e) {
      // 加载云验证数据异常
    }
  }
  
  /// 检查云端更新
  Future<void> _checkCloudUpdate() async {
    try {
      if (_cloudAppConfig == null) return;
      
      // 获取当前应用版本
      final currentVersion = Config.AppConfig.appVersion;
      
      // 比较版本
      final hasUpdate = _cloudService.isVersionNewer(currentVersion, _cloudAppConfig!.version);
      
      if (hasUpdate || _cloudAppConfig!.isForceUpdate) {
        print('AppProvider: 发现云端更新 - 当前版本: $currentVersion, 最新版本: ${_cloudAppConfig!.version}');
        print('AppProvider: 强制更新: ${_cloudAppConfig!.isForceUpdate}');
      }
    } catch (e) {
      print('AppProvider: 检查云端更新异常: $e');
    }
  }
  
  /// 手动刷新云验证数据
  Future<void> refreshCloudData() async {
    await _loadCloudVerificationData();
    notifyListeners();
  }
  
  /// 获取云端公告内容列表
  List<String> getCloudNotices() {
    return _cloudNotice?.formattedNotices ?? [];
  }
  
  /// 获取云端版本信息列表
  List<String> getCloudVersionInfo() {
    return _cloudAppConfig?.formattedVersionInfo ?? [];
  }
  
  /// 是否有云端更新
  Future<bool> hasCloudUpdate() async {
    try {
      if (_cloudAppConfig == null) return false;
      
      final currentVersion = Config.AppConfig.appVersion;
      
      return _cloudService.isVersionNewer(currentVersion, _cloudAppConfig!.version);
    } catch (e) {
      print('AppProvider: 检查是否有云端更新异常: $e');
      return false;
    }
  }
  
  /// 是否强制更新
  bool isForceCloudUpdate() {
    return _cloudAppConfig?.isForceUpdate ?? false;
  }

  // 在销毁时清理
  @override
  void dispose() {
    _mounted = false;
    _syncTimer?.cancel();
    super.dispose();
  }

  // 设置本地模式
  Future<void> setLocalMode(bool enabled) async {
    print('AppProvider: 设置本地模式: $enabled');
    
    if (enabled) {
      // 启用本地模式
      _user = User(
        id: 'local_user',
        username: '本地用户',
        email: '',
        avatarUrl: '',
      );
      
      // 清除API服务连接
      _apiService = null;
      _memosApiService = null;
      _resourceService = null;
      
      // 停止同步定时器
      _syncTimer?.cancel();
      _syncTimer = null;
      
      // 更新应用配置为本地模式
      _appConfig = _appConfig.copyWith(isLocalMode: true);
      await _preferencesService.saveAppConfig(_appConfig);
      
      // 初始化数据库
      await _databaseService.database;
      
      // 加载本地数据
      await loadNotesFromLocal();
      
      print('AppProvider: 本地模式已启用');
    } else {
      // 禁用本地模式
      _appConfig = _appConfig.copyWith(isLocalMode: false);
      await _preferencesService.saveAppConfig(_appConfig);
        _user = null;
      print('AppProvider: 本地模式已禁用');
    }
    
    notifyListeners();
  }
  

  // 设置当前用户
  Future<void> setUser(User user) async {
    _user = user;
    await _preferencesService.saveUser(user);
    notifyListeners();
  }

  /// 在后台初始化API服务，不阻塞启动流程
  Future<void> _initializeApiServiceInBackground() async {
    if (_memosApiService != null) return;
    
    // 检查是否启用自动登录
    if (!_appConfig.autoLogin) {
      if (kDebugMode) print('AppProvider: 未启用自动登录，跳过自动登录');
      return;
    }
    
    // 检查是否有保存的token和服务器信息
    final String? savedServerUrl = _appConfig.lastServerUrl ?? _user?.serverUrl;
    final String? savedToken = _appConfig.lastToken ?? _user?.token;
    
    if (savedServerUrl == null || savedToken == null) {
      if (kDebugMode) print('AppProvider: 缺少保存的服务器信息或token，跳过自动登录');
      return;
    }
    
    try {
      if (kDebugMode) print('AppProvider: 开始验证保存的token并尝试自动登录');
      
      // 尝试使用保存的token自动登录
      final loginResult = await loginWithToken(savedServerUrl, savedToken);
      
      if (loginResult.$1) {
        if (kDebugMode) print('AppProvider: 自动登录成功');
        
        // 初始化API服务
        _memosApiService = await ApiServiceFactory.createApiService(
          baseUrl: savedServerUrl,
          token: savedToken,
        ) as MemosApiServiceFixed;
        
        // 🚀 初始化增量同步服务（关键！）
        _incrementalSyncService = IncrementalSyncService(_databaseService, _memosApiService);
        if (kDebugMode) {
          print('AppProvider: 🚀 增量同步服务已在自动登录时初始化');
        }
        
        _resourceService = MemosResourceService(
          baseUrl: savedServerUrl,
          token: savedToken,
        );
        
        // 更新应用配置为在线模式
        if (_appConfig.isLocalMode) {
          if (kDebugMode) print('AppProvider: 切换到在线模式');
          _appConfig = _appConfig.copyWith(isLocalMode: false);
          await _preferencesService.saveAppConfig(_appConfig);
        }
        
        if (kDebugMode) print('AppProvider: API服务和资源服务初始化成功');
        
        // 启动自动同步
        startAutoSync();
        
        notifyListeners();
      } else {
        if (kDebugMode) print('AppProvider: 自动登录失败: ${loginResult.$2}，清除保存的登录信息');
        
        // Token无效，清除保存的登录信息
        await _preferencesService.clearLoginInfo();
        _user = null;
        _appConfig = _appConfig.copyWith(
          memosApiUrl: null,
          lastToken: null,
          lastServerUrl: null,
        );
        await _preferencesService.saveAppConfig(_appConfig);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('AppProvider: 自动登录过程中发生异常: $e');
      
      // 发生异常时清除保存的登录信息
      try {
        await _preferencesService.clearLoginInfo();
        _user = null;
        _appConfig = _appConfig.copyWith(
          memosApiUrl: null,
          lastToken: null,
          lastServerUrl: null,
        );
        await _preferencesService.saveAppConfig(_appConfig);
        notifyListeners();
      } catch (clearError) {
        if (kDebugMode) print('AppProvider: 清除登录信息时发生异常: $clearError');
      }
    }
  }

  /// 确保API服务已初始化
  /// 这个方法会快速检查并重新初始化API服务，避免重复的UI更新
  Future<void> _ensureApiServiceInitialized() async {
    if (_memosApiService != null) return;
    
    // 只在真正需要初始化时才显示消息
    _syncMessage = '初始化API服务...';
    notifyListeners();
    
    if (kDebugMode) print('AppProvider: API服务未初始化，尝试重新初始化');
    
    try {
      // 优先使用当前用户的Token
      if (_appConfig.memosApiUrl != null && _user?.token != null) {
        if (kDebugMode) print('AppProvider: 使用当前用户Token初始化API服务');
        _memosApiService = await ApiServiceFactory.createApiService(
          baseUrl: _appConfig.memosApiUrl!,
          token: _user!.token!,
        ) as MemosApiServiceFixed;
        
        // 同时初始化资源服务
        _resourceService = MemosResourceService(
          baseUrl: _appConfig.memosApiUrl!,
          token: _user!.token!,
        );
      } 
      // 备用：使用上次保存的Token
      else if (_appConfig.memosApiUrl != null && _appConfig.lastToken != null) {
        if (kDebugMode) print('AppProvider: 使用上次的Token初始化API服务');
        _memosApiService = await ApiServiceFactory.createApiService(
          baseUrl: _appConfig.memosApiUrl!,
          token: _appConfig.lastToken!,
        ) as MemosApiServiceFixed;
        
        // 同时初始化资源服务
        _resourceService = MemosResourceService(
          baseUrl: _appConfig.memosApiUrl!,
          token: _appConfig.lastToken!,
        );
      }
      
      if (_memosApiService == null) {
        throw Exception('API服务初始化失败：缺少必要的配置信息');
      }
      
      if (kDebugMode) print('AppProvider: API服务重新初始化成功');
    } catch (e) {
      if (kDebugMode) print('AppProvider: API服务初始化失败: $e');
      throw Exception('API服务初始化失败，无法获取数据');
    }
  }

  // 处理笔记中的引用关系
  Future<void> _processNoteReferences(Note note) async {
    try {
      // 🚀 使用统一引用管理器（静默处理）
      
      // 使用统一引用管理器的智能更新功能
      final success = await UnifiedReferenceManager().updateReferencesFromContent(note.id, note.content);
      
      // 🚀 处理完成（静默）
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 处理笔记引用关系失败: $e');
      }
    }
  }

  // 解析文本中的引用内容，获取被引用的笔记ID列表
  List<String> _parseReferencesFromText(String content) {
    final List<String> referencedIds = [];
    
    // 匹配 [引用内容] 格式
    final RegExp referenceRegex = RegExp(r'\[([^\]]+)\]');
    final matches = referenceRegex.allMatches(content);
    
    for (var match in matches) {
      final referenceContent = match.group(1);
      if (referenceContent != null && referenceContent.isNotEmpty) {
        if (kDebugMode) {
          print('AppProvider: 解析到引用内容: "$referenceContent"');
        }
        
        // 查找匹配这个内容的笔记
        final matchingNote = _notes.firstWhere(
          (note) => note.content.trim() == referenceContent.trim(),
          orElse: () => Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );
        
        if (matchingNote.id.isNotEmpty && !referencedIds.contains(matchingNote.id)) {
          referencedIds.add(matchingNote.id);
          if (kDebugMode) {
            print('AppProvider: 找到匹配的笔记 ID: ${matchingNote.id}');
          }
        } else {
          if (kDebugMode) {
            print('AppProvider: 没有找到匹配内容 "$referenceContent" 的笔记');
          }
        }
      }
    }
    
    return referencedIds;
  }

  // 创建单个引用关系


  // 同步所有引用关系（先删除旧的，再创建新的）
  Future<void> _syncAllReferenceRelations(String currentNoteId, List<String> relatedMemoIds) async {
    try {
      if (!isLoggedIn || _user?.token == null || _appConfig.memosApiUrl == null) return;
      
      if (kDebugMode) {
        print('AppProvider: 开始同步引用关系，目标: ${relatedMemoIds.length} 个');
      }
      
      // 1. 先删除服务器上所有现有的引用关系
      if (kDebugMode) {
        print('AppProvider: 准备删除服务器上笔记 $currentNoteId 的所有现有引用关系');
      }
      final deleteSuccess = await _deleteAllReferenceRelations(currentNoteId);
      if (kDebugMode) {
        print('AppProvider: 删除服务器现有引用关系: ${deleteSuccess ? "成功" : "失败"}');
      }
      
      // 2. 再创建新的引用关系
      int successCount = 0;
      int failureCount = 0;
      
      for (String relatedMemoId in relatedMemoIds) {
        final success = await _syncSingleReferenceToServer(currentNoteId, {
          'relatedMemoId': relatedMemoId,
          'type': 'REFERENCE',
        });
        
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }
      
      if (kDebugMode) {
        print('AppProvider: 引用关系同步完成，成功: $successCount, 失败: $failureCount');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 同步引用关系异常: $e');
      }
    }
  }
  
  // 删除服务器上笔记的所有引用关系
  Future<bool> _deleteAllReferenceRelations(String noteId) async {
    try {
      // 使用v1 API: DELETE /api/v1/memo/{memoId}/relation
      final url = '${_appConfig.memosApiUrl}/api/v1/memo/$noteId/relation';
      final headers = {
        'Authorization': 'Bearer ${_user!.token}',
        'Content-Type': 'application/json',
      };
      
      final response = await NetworkUtils.directDelete(
        Uri.parse(url),
        headers: headers,
      );
      
      if (kDebugMode) {
        print('AppProvider: 删除笔记 $noteId 所有引用关系, 状态: ${response.statusCode}');
        if (response.statusCode != 200) {
          print('AppProvider: 删除引用关系失败，响应: ${response.body}');
        }
      }
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 删除引用关系失败: $e');
      }
      return false;
    }
  }

  // 🔧 数据恢复：重新构建所有引用关系
  Future<void> rebuildAllReferences() async {
    try {
      if (kDebugMode) {
        print('AppProvider: 🔧 开始重建所有引用关系');
      }
      
      int totalRebuilt = 0;
      
      // 🔧 首先清理所有现有的引用关系，重新开始
      for (var note in _notes) {
        if (note.relations.isNotEmpty) {
          final cleanNote = note.copyWith(relations: <Map<String, dynamic>>[]);
          await _databaseService.updateNote(cleanNote);
        }
      }
      
      // 重新加载清理后的笔记
      await loadNotesFromLocal();
      
      // 🚀 遍历所有笔记，重新解析引用关系（静默处理）
      for (var note in _notes) {
        
        // 使用UnifiedReferenceManager重新处理每个笔记
        final success = await UnifiedReferenceManager().updateReferencesFromContent(note.id, note.content);
        if (success) {
          totalRebuilt++;
        }
        
        // 添加小延迟避免处理过快
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // 重新加载笔记以获取最新的引用关系
      await loadNotesFromLocal();
      
      if (kDebugMode) {
        // 🚀 只打印汇总，不打印每条笔记（避免137行日志）
        final totalRelations = _notes.fold(0, (sum, n) => sum + n.relations.length);
        print('AppProvider: ✅ 引用关系重建完成 - $totalRebuilt笔记 $totalRelations关系');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: ❌ 重建引用关系失败: $e');
      }
    }
  }

  // 处理Token过期的情况
  Future<void> _handleTokenExpired() async {
    try {
      if (kDebugMode) print('AppProvider: 处理Token过期，清除登录状态');
      
      // 1. 停止自动同步
      stopAutoSync();
      
      // 2. 尝试撤销过期的token（尽力而为）
      if (_memosApiService != null) {
        try {
          await _memosApiService!.logout();
          if (kDebugMode) print('AppProvider: 过期token撤销成功');
        } catch (e) {
          if (kDebugMode) print('AppProvider: 过期token撤销失败: $e');
          // 继续执行，因为token已经过期
        }
      }
      
      // 3. 清除API服务
      _memosApiService = null;
      _resourceService = null;
      
      // 4. 清除用户信息和登录状态
      await _preferencesService.clearLoginInfo();
      _user = null;
      
      // 5. 更新应用配置，切换到本地模式
      _appConfig = _appConfig.copyWith(
        isLocalMode: true,
        memosApiUrl: null,
        lastToken: null,
        lastServerUrl: null,
        autoLogin: false, // 禁用自动登录
      );
      await _preferencesService.saveAppConfig(_appConfig);
      
      // 6. 设置同步消息提示用户
      _syncMessage = 'Token已过期，请重新登录';
      _isSyncing = false;
      
      // 7. 通知UI更新
      notifyListeners();
      
      if (kDebugMode) print('AppProvider: Token过期处理完成，已切换到本地模式');
    } catch (e) {
      if (kDebugMode) print('AppProvider: 处理Token过期时发生错误: $e');
    }
  }

  // 🖼️ 异步预加载用户头像
  void _preloadUserAvatarAsync() {
    if (_user?.avatarUrl == null || _user!.avatarUrl!.trim().isEmpty) {
      return; // 没有头像URL，无需预加载
    }

    // 在微任务中执行预加载，避免阻塞主线程
    Future.microtask(() async {
      try {
        // 使用NavigatorState获取context，但只在widget树构建完成后
        final context = NavigatorKey.currentContext;
        if (context != null && _user != null) {
          print('AppProvider: 开始预加载用户头像');
          await AvatarPreloader.preloadUserAvatar(context, _user!);
          print('AppProvider: 用户头像预加载完成');
        }
      } catch (e) {
        // 预加载失败不影响正常功能
        print('AppProvider: 头像预加载失败（不影响正常使用）: $e');
      }
    });
  }

  // ==================== 提醒管理功能 ====================

  /// 为笔记设置提醒时间
  Future<bool> setNoteReminder(String noteId, DateTime reminderTime) async {
    try {
      // 查找笔记
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        throw Exception('笔记不存在');
      }

      final note = _notes[noteIndex];
      
      // 更新笔记的提醒时间
      final updatedNote = note.copyWith(reminderTime: reminderTime);
      _notes[noteIndex] = updatedNote;
      
      // 保存到数据库
      await _databaseService.updateNote(updatedNote);
      
      // 设置通知（传递原始noteId字符串）
      final success = await _notificationService.scheduleNoteReminder(
        noteId: noteId.hashCode,
        noteIdString: noteId, // 🔥 传递原始字符串ID
        title: '📝 笔记提醒',
        body: note.content.length > 50 
            ? '${note.content.substring(0, 50)}...' 
            : note.content,
        reminderTime: reminderTime,
      );
      
      notifyListeners();
      
      if (kDebugMode) {
        if (success) {
          print('AppProvider: 成功设置笔记提醒，时间: $reminderTime');
        } else {
          print('AppProvider: ⚠️ 提醒设置失败，可能是权限问题');
        }
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 设置笔记提醒失败: $e');
      }
      rethrow;
    }
  }

  /// 取消笔记提醒
  Future<void> cancelNoteReminder(String noteId) async {
    try {
      // 查找笔记
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        throw Exception('笔记不存在');
      }

      final note = _notes[noteIndex];
      
      // 清除笔记的提醒时间
      final updatedNote = note.copyWith(clearReminderTime: true);
      _notes[noteIndex] = updatedNote;
      
      // 保存到数据库
      await _databaseService.updateNote(updatedNote);
      
      // 取消通知（使用hashCode将String ID转为int）
      await _notificationService.cancelNoteReminder(noteId.hashCode);
      
      notifyListeners();
      
      if (kDebugMode) {
        print('AppProvider: 成功取消笔记提醒');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppProvider: 取消笔记提醒失败: $e');
      }
      rethrow;
    }
  }

  /// 获取笔记的提醒时间（不自动清理，只返回数据）
  /// 参考大厂应用：UI查询不应触发业务逻辑，过期清理应由定时任务处理
  DateTime? getNoteReminderTime(String noteId) {
    try {
      final note = _notes.firstWhere((note) => note.id == noteId);
      return note.reminderTime;
    } catch (e) {
      return null;
    }
  }
  
  /// 清理所有过期的提醒（应用启动时调用）
  /// 参考大厂应用：只清理已经过期超过1分钟的提醒，避免误删刚设置的提醒
  Future<void> clearExpiredReminders() async {
    try {
      final now = DateTime.now();
      // 给1分钟的宽限期，避免时区、时间同步等问题导致的误删
      final threshold = now.subtract(const Duration(minutes: 1));
      int clearedCount = 0;
      
      for (final note in _notes) {
        // 只清理已经过期超过1分钟的提醒
        if (note.reminderTime != null && note.reminderTime!.isBefore(threshold)) {
          if (kDebugMode) {
            print('AppProvider: 清理过期提醒 - 笔记: ${note.id}, 时间: ${note.reminderTime}');
          }
          await cancelNoteReminder(note.id);
          clearedCount++;
        }
      }
      
      if (clearedCount > 0) {
        if (kDebugMode) {
          print('AppProvider: 🧹 已清理 $clearedCount 个过期提醒');
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('AppProvider: 清理过期提醒失败: $e');
    }
  }
}

// 用于获取全局Context的导航键
class NavigatorKey {
  static final GlobalKey<NavigatorState> _key = GlobalKey<NavigatorState>();
  
  static GlobalKey<NavigatorState> get key => _key;
  static BuildContext? get currentContext => _key.currentContext;
} 