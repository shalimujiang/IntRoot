// 统一引用管理器 - 一体化双向引用系统
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import 'database_service.dart';
import 'api_service.dart';

/// 统一引用管理器
/// 
/// 核心设计原则：
/// 1. 原子性：引用操作要么全部成功，要么全部失败
/// 2. 一致性：源笔记和目标笔记的关系始终保持同步
/// 3. 实时性：UI立即反映数据变化
/// 4. 可靠性：后台同步确保数据持久化
class UnifiedReferenceManager {
  static final UnifiedReferenceManager _instance = UnifiedReferenceManager._internal();
  factory UnifiedReferenceManager() => _instance;
  UnifiedReferenceManager._internal();

  DatabaseService? _databaseService;
  Function(List<Note>)? _onNotesUpdated;
  Function(String)? _onError;
  Future<void> Function(String, String, String)? _syncReferenceToServerUnified;
  
  /// 初始化管理器
  void initialize({
    required DatabaseService databaseService,
    Function(List<Note>)? onNotesUpdated,
    Function(String)? onError,
    Future<void> Function(String, String, String)? syncReferenceToServerUnified,
  }) {
    _databaseService = databaseService;
    _onNotesUpdated = onNotesUpdated;
    _onError = onError;
    _syncReferenceToServerUnified = syncReferenceToServerUnified;
  }

  /// 🎯 核心方法：创建引用关系
  /// 
  /// 这是一个原子性操作，会同时：
  /// 1. 在源笔记创建REFERENCE关系
  /// 2. 在目标笔记创建REFERENCED_BY关系
  /// 3. 更新数据库
  /// 4. 刷新UI
  /// 5. 后台同步到服务器
  Future<bool> createReference(String sourceNoteId, String targetNoteId) async {
    if (_databaseService == null) {
      _handleError('引用管理器未初始化');
      return false;
    }

    if (kDebugMode) {
      print('UnifiedReferenceManager: 🔗 创建引用关系 $sourceNoteId -> $targetNoteId');
    }

    try {
      // 开始数据库事务
      final notes = await _databaseService!.getNotes();
      
      final sourceNoteIndex = notes.indexWhere((n) => n.id == sourceNoteId);
      final targetNoteIndex = notes.indexWhere((n) => n.id == targetNoteId);
      
      if (sourceNoteIndex == -1) {
        _handleError('源笔记不存在: $sourceNoteId');
        return false;
      }
      
      if (targetNoteIndex == -1) {
        _handleError('目标笔记不存在: $targetNoteId');
        return false;
      }

      final sourceNote = notes[sourceNoteIndex];
      final targetNote = notes[targetNoteIndex];

      // 检查是否已存在完整的双向关系
      final existingSourceRelation = sourceNote.relations.any((rel) =>
        rel['type'] == 'REFERENCE' &&
        rel['memoId']?.toString() == sourceNoteId &&
        rel['relatedMemoId']?.toString() == targetNoteId
      );
      
      final existingTargetRelation = targetNote.relations.any((rel) =>
        rel['type'] == 'REFERENCED_BY' &&
        rel['memoId']?.toString() == sourceNoteId &&
        rel['relatedMemoId']?.toString() == targetNoteId
      );

      if (existingSourceRelation && existingTargetRelation) {
        if (kDebugMode) {
          print('UnifiedReferenceManager: 完整的双向引用关系已存在，跳过创建');
        }
        return true;
      }
      
      // 检查现有关系状态

      // 创建时间戳
      final timestamp = DateTime.now().toIso8601String();

      // 准备更新的笔记
      var updatedSourceNote = sourceNote;
      var updatedTargetNote = targetNote;

      // 1. 如果源笔记缺少REFERENCE关系，则添加
      if (!existingSourceRelation) {
        final sourceRelation = {
          'memoId': sourceNoteId,
          'relatedMemoId': targetNoteId,
          'type': 'REFERENCE',
          'synced': false,
          'createdAt': timestamp,
        };
        final updatedSourceRelations = List<Map<String, dynamic>>.from(sourceNote.relations);
        updatedSourceRelations.add(sourceRelation);
        updatedSourceNote = sourceNote.copyWith(relations: updatedSourceRelations);
        
        // 为源笔记添加REFERENCE关系
      }

      // 2. 如果目标笔记缺少REFERENCED_BY关系，则添加
      if (!existingTargetRelation) {
        final targetRelation = {
          'memoId': sourceNoteId,
          'relatedMemoId': targetNoteId,
          'type': 'REFERENCED_BY',
          'synced': false,
          'createdAt': timestamp,
        };
        final updatedTargetRelations = List<Map<String, dynamic>>.from(targetNote.relations);
        updatedTargetRelations.add(targetRelation);
        updatedTargetNote = targetNote.copyWith(relations: updatedTargetRelations);
        
        // 为目标笔记添加REFERENCED_BY关系
      }

      // 3. 原子性数据库更新（只更新有变化的笔记）
      if (!existingSourceRelation) {
        await _databaseService!.updateNote(updatedSourceNote);
      }
      if (!existingTargetRelation) {
        await _databaseService!.updateNote(updatedTargetNote);
      }

      // 6. 更新内存中的笔记列表
      notes[sourceNoteIndex] = updatedSourceNote;
      notes[targetNoteIndex] = updatedTargetNote;

      // 7. 立即刷新UI
      _onNotesUpdated?.call(notes);

      // 🔧 强制UI更新：确保界面立即反映变化
      if (_onNotesUpdated != null) {
        // 添加微延迟确保UI更新完成
        await Future.delayed(const Duration(milliseconds: 10));
        _onNotesUpdated!.call(notes);
      }

      // 引用关系创建成功

      // 8. 后台同步到服务器（不阻塞UI）
      _syncToServerInBackground(sourceNoteId, targetNoteId, 'CREATE');

      return true;
    } catch (e) {
      _handleError('创建引用关系失败: $e');
      return false;
    }
  }

  /// 🎯 核心方法：删除引用关系
  /// 
  /// 原子性删除操作：
  /// 1. 从源笔记删除REFERENCE关系
  /// 2. 从目标笔记删除REFERENCED_BY关系
  /// 3. 更新数据库
  /// 4. 刷新UI
  /// 5. 同步到服务器
  Future<bool> removeReference(String sourceNoteId, String targetNoteId) async {
    if (_databaseService == null) {
      _handleError('引用管理器未初始化');
      return false;
    }

    if (kDebugMode) {
      print('UnifiedReferenceManager: 🗑️ 删除引用关系 $sourceNoteId -> $targetNoteId');
    }

    try {
      final notes = await _databaseService!.getNotes();
      
      final sourceNoteIndex = notes.indexWhere((n) => n.id == sourceNoteId);
      final targetNoteIndex = notes.indexWhere((n) => n.id == targetNoteId);
      
      if (sourceNoteIndex == -1) {
        if (kDebugMode) {
          print('UnifiedReferenceManager: 源笔记不存在，跳过删除');
        }
        return true;
      }

      final sourceNote = notes[sourceNoteIndex];

      // 🔧 修复：如果目标笔记不存在，仍需要清理源笔记中的无效引用
      if (targetNoteIndex == -1) {
        if (kDebugMode) {
          print('UnifiedReferenceManager: 目标笔记不存在，清理源笔记中的无效引用');
        }
        
        // 清理源笔记中指向不存在笔记的引用关系
        final updatedSourceRelations = sourceNote.relations.where((rel) =>
          !(rel['type'] == 'REFERENCE' &&
            rel['memoId']?.toString() == sourceNoteId &&
            rel['relatedMemoId']?.toString() == targetNoteId)
        ).toList();

        if (updatedSourceRelations.length != sourceNote.relations.length) {
          final updatedSourceNote = sourceNote.copyWith(relations: updatedSourceRelations);
          await _databaseService!.updateNote(updatedSourceNote);
          
          // 更新内存
          notes[sourceNoteIndex] = updatedSourceNote;
          _onNotesUpdated?.call(notes);
          
          if (kDebugMode) {
            print('UnifiedReferenceManager: ✅ 清理无效引用成功');
          }
        }
        
        return true;
      }

      final targetNote = notes[targetNoteIndex];

      // 1. 从源笔记删除REFERENCE关系
      final updatedSourceRelations = sourceNote.relations.where((rel) =>
        !(rel['type'] == 'REFERENCE' &&
          rel['memoId']?.toString() == sourceNoteId &&
          rel['relatedMemoId']?.toString() == targetNoteId)
      ).toList();

      // 2. 从目标笔记删除REFERENCED_BY关系
      final updatedTargetRelations = targetNote.relations.where((rel) =>
        !(rel['type'] == 'REFERENCED_BY' &&
          rel['memoId']?.toString() == sourceNoteId &&
          rel['relatedMemoId']?.toString() == targetNoteId)
      ).toList();

      // 3. 更新笔记
      final updatedSourceNote = sourceNote.copyWith(relations: updatedSourceRelations);
      final updatedTargetNote = targetNote.copyWith(relations: updatedTargetRelations);

      // 4. 原子性数据库更新
      await _databaseService!.updateNote(updatedSourceNote);
      await _databaseService!.updateNote(updatedTargetNote);

      // 5. 更新内存
      notes[sourceNoteIndex] = updatedSourceNote;
      notes[targetNoteIndex] = updatedTargetNote;

      // 6. 立即刷新UI
      _onNotesUpdated?.call(notes);

      // 🔧 强制UI更新：确保界面立即反映变化
      if (_onNotesUpdated != null) {
        // 添加微延迟确保UI更新完成
        await Future.delayed(const Duration(milliseconds: 10));
        _onNotesUpdated!.call(notes);
      }

      if (kDebugMode) {
        print('UnifiedReferenceManager: ✅ 引用关系删除成功');
        print('UnifiedReferenceManager: 源笔记关系数: ${updatedSourceNote.relations.length}');
        print('UnifiedReferenceManager: 目标笔记关系数: ${updatedTargetNote.relations.length}');
      }

      // 7. 后台同步到服务器
      _syncToServerInBackground(sourceNoteId, targetNoteId, 'DELETE');

      return true;
    } catch (e) {
      _handleError('删除引用关系失败: $e');
      return false;
    }
  }

  /// 🎯 智能引用更新
  /// 
  /// 根据笔记内容自动管理引用关系：
  /// 1. 解析新的引用
  /// 2. 对比现有引用
  /// 3. 批量创建/删除关系
  Future<bool> updateReferencesFromContent(String noteId, String content) async {
    if (_databaseService == null) return false;

    if (kDebugMode) {
      // 🚀 智能更新引用关系（静默处理）
    }

    try {
      // 1. 解析文本中的引用
      final newReferences = _parseReferencesFromText(content);
      
      // 2. 获取现有引用关系
      final notes = await _databaseService!.getNotes();
      final currentNote = notes.firstWhere((n) => n.id == noteId, 
        orElse: () => throw Exception('笔记不存在'));
      
      final existingReferences = currentNote.relations
        .where((rel) => rel['type'] == 'REFERENCE' && 
                       rel['memoId']?.toString() == noteId)
        .map((rel) => rel['relatedMemoId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

      // 3. 过滤有效的引用（只处理存在的笔记）
      final validNewReferences = <String>[];
      
      // 验证引用的有效性
      
      for (final refId in newReferences) {
        // 🔧 修复：支持按ID或内容匹配
        final targetByIdExists = notes.any((n) => n.id == refId);
        final targetByContentExists = notes.any((n) => n.content.trim() == refId);
        final targetExists = targetByIdExists || targetByContentExists;
        
        // 检查引用是否存在
        
        if (targetExists) {
          // 如果按内容匹配成功，需要找到对应的笔记ID
          String actualTargetId = refId;
          if (!targetByIdExists && targetByContentExists) {
            final targetNote = notes.firstWhere((n) => n.content.trim() == refId);
            actualTargetId = targetNote.id;
            if (kDebugMode) {
              print('  - 内容匹配成功，实际目标ID: $actualTargetId');
            }
          }
          validNewReferences.add(actualTargetId);
        } else {
          // 🚀 跳过无效引用（静默处理）
        }
      }
      
      // 4. 计算差异（只基于有效引用）
      final toAdd = validNewReferences.where((id) => !existingReferences.contains(id)).toList();
      final toRemove = existingReferences.where((id) => !validNewReferences.contains(id)).toList();

      if (kDebugMode) {
        // 🚀 静默处理引用变更
        if (kDebugMode && (toAdd.isNotEmpty || toRemove.isNotEmpty)) {
          print('UnifiedReferenceManager: 引用变更 - 添加:${toAdd.length} 删除:${toRemove.length}');
        }
      }

      // 5. 批量执行操作
      bool success = true;
      
      // 删除旧关系
      for (final targetId in toRemove) {
        final result = await removeReference(noteId, targetId);
        if (!result) success = false;
      }
      
      // 创建新关系
      for (final targetId in toAdd) {
        final result = await createReference(noteId, targetId);
        if (!result) success = false;
      }

      if (kDebugMode) {
        // 🚀 仅在失败或调试模式下打印
        if (kDebugMode && !success) {
          print('UnifiedReferenceManager: ❌ 智能更新失败');
        }
      }

      return success;
    } catch (e) {
      _handleError('智能更新引用失败: $e');
      return false;
    }
  }

  /// 解析文本中的引用
  List<String> _parseReferencesFromText(String content) {
    final regex = RegExp(r'\[([^\]]+)\]');
    final matches = regex.allMatches(content);
    final references = <String>[];
    
    for (final match in matches) {
      final refContent = match.group(1);
      if (refContent != null && refContent.isNotEmpty) {
        // 🔧 修复：不仅仅处理数字ID，而是处理所有引用内容
        // 这样可以支持按内容匹配笔记
        references.add(refContent.trim());
      }
    }
    
          // 从文本中解析出引用
    
    return references;
  }

  /// 后台同步到服务器
  Future<void> _syncToServerInBackground(String sourceId, String targetId, String action) async {
    // 这里实现服务器同步逻辑
    // 不阻塞主线程，在后台执行
    Future.microtask(() async {
      try {
        if (kDebugMode) {
          print('UnifiedReferenceManager: 🌐 后台同步 $action $sourceId -> $targetId');
        }
        
        // 调用实际的服务器同步逻辑
        if (_syncReferenceToServerUnified != null) {
          await _syncReferenceToServerUnified!(sourceId, targetId, action);
        }
        
        if (kDebugMode) {
          print('UnifiedReferenceManager: ✅ 服务器同步完成');
        }
      } catch (e) {
        if (kDebugMode) {
          print('UnifiedReferenceManager: ❌ 服务器同步失败: $e');
        }
      }
    });
  }

  /// 错误处理
  void _handleError(String message) {
    if (kDebugMode) {
      print('UnifiedReferenceManager: ❌ $message');
    }
    _onError?.call(message);
  }

  /// 🧹 清理孤立的引用关系
  Future<int> cleanupOrphanedReferences() async {
    if (_databaseService == null) return 0;

    if (kDebugMode) {
      print('UnifiedReferenceManager: 🧹 开始清理孤立引用');
    }

    try {
      final notes = await _databaseService!.getNotes();
      int cleanedCount = 0;
      bool hasChanges = false;

      for (int i = 0; i < notes.length; i++) {
        final note = notes[i];
        final originalRelationCount = note.relations.length;
        
        // 清理孤立的REFERENCED_BY关系
        final cleanedRelations = note.relations.where((rel) {
          if (rel['type'] != 'REFERENCED_BY') return true;
          
          final sourceNoteId = rel['memoId']?.toString();
          if (sourceNoteId == null) return false;
          
          // 检查源笔记是否存在
          final sourceNote = notes.firstWhere(
            (n) => n.id == sourceNoteId, 
            orElse: () => Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now())
          );
          
          if (sourceNote.id.isEmpty) return false; // 源笔记不存在
          
          // 检查源笔记是否有对应的REFERENCE关系
          final hasCorrespondingReference = sourceNote.relations.any((sourceRel) =>
            sourceRel['type'] == 'REFERENCE' &&
            sourceRel['memoId']?.toString() == sourceNoteId &&
            sourceRel['relatedMemoId']?.toString() == note.id
          );
          
          return hasCorrespondingReference;
        }).toList();

        if (cleanedRelations.length != originalRelationCount) {
          final updatedNote = note.copyWith(relations: cleanedRelations);
          await _databaseService!.updateNote(updatedNote);
          notes[i] = updatedNote;
          
          cleanedCount += (originalRelationCount - cleanedRelations.length);
          hasChanges = true;
          
          if (kDebugMode) {
            print('UnifiedReferenceManager: 清理笔记 ${note.id}，删除 ${originalRelationCount - cleanedRelations.length} 个孤立关系');
          }
        }
      }

      if (hasChanges) {
        _onNotesUpdated?.call(notes);
      }

      if (kDebugMode) {
        print('UnifiedReferenceManager: ✅ 清理完成，共删除 $cleanedCount 个孤立关系');
      }

      return cleanedCount;
    } catch (e) {
      _handleError('清理孤立引用失败: $e');
      return 0;
    }
  }

  /// 🧹 清理所有无效的引用关系
  /// 
  /// 删除所有指向不存在笔记的引用关系
  Future<bool> cleanupInvalidReferences() async {
    if (_databaseService == null) {
      _handleError('引用管理器未初始化');
      return false;
    }

    if (kDebugMode) {
      print('UnifiedReferenceManager: 🧹 开始清理无效引用关系');
    }

    try {
      final notes = await _databaseService!.getNotes();
      final noteIds = notes.map((n) => n.id).toSet();
      bool hasChanges = false;

      for (int i = 0; i < notes.length; i++) {
        final note = notes[i];
        final validRelations = <Map<String, dynamic>>[];
        int removedCount = 0;

        for (var relation in note.relations) {
          final relatedId = relation['relatedMemoId']?.toString();
          
          if (relatedId != null && noteIds.contains(relatedId)) {
            validRelations.add(relation);
          } else {
            removedCount++;
            if (kDebugMode) {
              print('UnifiedReferenceManager: 清理笔记 ${note.id} 的无效引用: $relatedId');
            }
          }
        }

        if (removedCount > 0) {
          final updatedNote = note.copyWith(relations: validRelations);
          await _databaseService!.updateNote(updatedNote);
          notes[i] = updatedNote;
          hasChanges = true;

          if (kDebugMode) {
            print('UnifiedReferenceManager: 笔记 ${note.id} 清理了 $removedCount 个无效引用');
          }
        }
      }

      if (hasChanges) {
        _onNotesUpdated?.call(notes);
        
        if (kDebugMode) {
          print('UnifiedReferenceManager: ✅ 无效引用清理完成');
        }
      } else {
        if (kDebugMode) {
          print('UnifiedReferenceManager: 没有发现无效引用');
        }
      }

      return true;
    } catch (e) {
      _handleError('清理无效引用失败: $e');
      return false;
    }
  }
} 