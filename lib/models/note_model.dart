import 'dart:convert';
import 'package:flutter/foundation.dart';

class Note {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime displayTime;
  final List<String> tags;
  final String creator;
  bool isSynced;
  final bool isPinned;
  final String visibility;
  final List<Map<String, dynamic>> resourceList; // 添加资源列表
  final List<Map<String, dynamic>> relations; // 添加关系列表
  final DateTime? reminderTime; // 提醒时间

  Note({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    DateTime? displayTime,
    List<String>? tags,
    String? creator,
    this.isSynced = false,
    this.isPinned = false,
    this.visibility = 'PRIVATE',
    List<Map<String, dynamic>>? resourceList,
    List<Map<String, dynamic>>? relations,
    this.reminderTime,
  }) : this.displayTime = displayTime ?? updatedAt,
       this.tags = tags ?? [],
       this.creator = creator ?? 'local',
       this.resourceList = resourceList ?? [],
       this.relations = relations ?? [];

  Note copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? displayTime,
    List<String>? tags,
    String? creator,
    bool? isSynced,
    bool? isPinned,
    String? visibility,
    List<Map<String, dynamic>>? resourceList,
    List<Map<String, dynamic>>? relations,
    DateTime? reminderTime,
    bool clearReminderTime = false,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayTime: displayTime ?? this.displayTime,
      tags: tags ?? this.tags,
      creator: creator ?? this.creator,
      isSynced: isSynced ?? this.isSynced,
      isPinned: isPinned ?? this.isPinned,
      visibility: visibility ?? this.visibility,
      resourceList: resourceList ?? this.resourceList,
      relations: relations ?? this.relations,
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'displayTime': displayTime.toIso8601String(),
      'tags': tags.join(','),
      'creator': creator,
      'is_synced': isSynced ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'visibility': visibility,
      'resourceList': json.encode(resourceList), // 将resourceList序列化为JSON字符串
      'relations': json.encode(relations), // 将relations序列化为JSON字符串
      'reminder_time': reminderTime?.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    // if (kDebugMode) print('Note.fromMap: 数据库数据: ${map.toString()}');
    
    // 处理resourceList
    List<Map<String, dynamic>> resourceList = [];
    if (map['resourceList'] != null && map['resourceList'].isNotEmpty) {
      // if (kDebugMode) print('Note.fromMap: resourceList原始数据: ${map['resourceList']}');
      try {
        final decoded = json.decode(map['resourceList']);
        resourceList = List<Map<String, dynamic>>.from(decoded);
        // if (kDebugMode) print('Note.fromMap: resourceList解析成功，长度: ${resourceList.length}');
      } catch (e) {
        if (kDebugMode) print('Note.fromMap: 解析resourceList失败: $e');
      }
    } else {
      // if (kDebugMode) print('Note.fromMap: resourceList为空或null');
    }
    
    // 处理relations
    List<Map<String, dynamic>> relations = [];
    if (map['relations'] != null && map['relations'].isNotEmpty) {
      try {
        final decoded = json.decode(map['relations']);
        relations = List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        if (kDebugMode) print('Note.fromMap: 解析relations失败: $e');
      }
    }
    
    final note = Note(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      displayTime: map['displayTime'] != null 
          ? DateTime.parse(map['displayTime'])
          : null,
      tags: map['tags'] != null && map['tags'].isNotEmpty 
          ? map['tags'].split(',') 
          : null,
      creator: map['creator'],
      isSynced: map['is_synced'] == 1,
      isPinned: map['isPinned'] == 1,
      visibility: map['visibility'] ?? 'PRIVATE',
      resourceList: resourceList,
      relations: relations,
      reminderTime: map['reminder_time'] != null 
          ? DateTime.parse(map['reminder_time'])
          : null,
    );
    
    // if (kDebugMode) print('Note.fromMap: 创建的Note resourceList长度: ${note.resourceList.length}');
    return note;
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    // if (kDebugMode) print('Note.fromJson: 原始JSON数据: ${json.toString().substring(0, 200)}...');
    
    // 处理时间戳 - Memos API 返回的是秒级时间戳，需要转换为毫秒
    int createdTsSeconds = json['createdTs'] as int;
    int updatedTsSeconds = json['updatedTs'] as int;
    
    // 转换为毫秒级时间戳
    DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(createdTsSeconds * 1000);
    DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedTsSeconds * 1000);
    
    // 🚀 处理资源列表（移除冗余日志）
    List<Map<String, dynamic>> resourceList = [];
    if (json['resourceList'] != null) {
      resourceList = List<Map<String, dynamic>>.from(json['resourceList']);
    }
    
    // 🚀 处理关系列表（移除冗余日志）
    List<Map<String, dynamic>> relations = [];
    if (json['relationList'] != null) {
      relations = List<Map<String, dynamic>>.from(json['relationList']);
    } else if (json['relations'] != null) {
      relations = List<Map<String, dynamic>>.from(json['relations']);
    }
    
    final note = Note(
      id: json['id'].toString(),
      content: json['content'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      displayTime: json['displayTime'] != null 
          ? DateTime.parse(json['displayTime'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      creator: json['creator']?.toString(),
      isSynced: true,
      isPinned: json['pinned'] ?? false,
      visibility: json['visibility'] ?? 'PRIVATE',
      resourceList: resourceList,
      relations: relations,
    );
    
    return note;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdTs': createdAt.millisecondsSinceEpoch,
      'updatedTs': updatedAt.millisecondsSinceEpoch,
      'displayTime': displayTime.toIso8601String(),
      'tags': tags,
      'creator': creator,
      'pinned': isPinned,
      'visibility': visibility,
    };
  }

  // 从笔记内容中提取标签
  static List<String> extractTagsFromContent(String content) {
    final RegExp tagRegex = RegExp(r'#([\p{L}\p{N}_\u4e00-\u9fff]+)', unicode: true);
    final matches = tagRegex.allMatches(content);
    return matches
      .map((match) => match.group(1))
      .where((tag) => tag != null)
      .map((tag) => tag!)
      .toList();
  }

  // 判断可见性
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isProtected => visibility == 'PROTECTED';
  bool get isPublic => visibility == 'PUBLIC';
} 