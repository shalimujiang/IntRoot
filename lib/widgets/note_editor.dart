import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../themes/app_theme.dart';
import '../utils/snackbar_utils.dart';
import '../utils/network_utils.dart';
import '../providers/app_provider.dart';
import '../services/local_reference_service.dart';
import 'package:http/io_client.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/note_model.dart';
import '../services/speech_service.dart';

class NoteEditor extends StatefulWidget {
  final Function(String content) onSave;
  final String? initialContent;
  final String? currentNoteId; // 当前编辑的笔记ID，用于建立引用关系
  
  const NoteEditor({
    super.key,
    required this.onSave,
    this.initialContent,
    this.currentNoteId,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  bool _canSave = false;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  // 语音识别动画控制器
  late AnimationController _speechAnimationController;
  
  // 单行文本的估计高度
  final double _singleLineHeight = 22.0; // 字体大小 * 行高
  
  // 最大显示的行数
  final int _maxLines = 10;
  
  // 文本内容行数
  int _lineCount = 0;
  
  // 文本样式
  static const TextStyle _textStyle = TextStyle(
    fontSize: 16.0,
    height: 1.375, // 行高是字体大小的1.375倍
    letterSpacing: 0.1,
    color: Color(0xFF333333),
  );
  
  // 提示文本样式
  late final TextStyle _hintStyle = _textStyle.copyWith(
    color: Colors.grey.shade400,
  );

  // 添加一个标志来防止多次保存
  bool _isSaving = false;
  
  // 是否显示更多选项
  bool _showingMoreOptions = false;
  
  // 添加图片列表和Markdown代码
  List<_ImageItem> _imageList = [];
  List<String> _mdCodes = [];
  final ScrollController _imageScrollController = ScrollController();
  
  // 语音识别相关
  final SpeechService _speechService = SpeechService();
  bool _isSpeechListening = false;
  String _partialSpeechText = '';
  double _soundLevel = 0.0; // 声音级别，用于音波动画
  bool _continuousMode = true; // 连续识别模式

  // 从Markdown中提取图片路径
  void _extractImagesFromMarkdown() {
    final RegExp imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    final matches = imageRegex.allMatches(_textController.text);
    
    // 提取所有图片链接和描述
    List<_ImageItem> newImageList = [];
    List<String> markdownCodes = [];
    
    for (var match in matches) {
      final alt = match.group(1) ?? '图片';
      final path = match.group(2) ?? '';
      final fullMatch = match.group(0) ?? '';
      
      if (path.isNotEmpty) {
        newImageList.add(_ImageItem(path: path, alt: alt));
        markdownCodes.add(fullMatch);
      }
    }
    
    setState(() {
      _imageList = newImageList;
      _mdCodes = markdownCodes;
      
      // 从文本中移除所有图片Markdown代码
      String newText = _textController.text;
      for (var code in markdownCodes) {
        newText = newText.replaceAll(code, '');
      }
      
      // 更新文本，但不触发监听器
      _textController.removeListener(_updateLineCount);
      _textController.text = newText;
      _textController.addListener(_updateLineCount);
    });
  }

  // 更新内容行数
  void _updateLineCount() {
    setState(() {
      _lineCount = '\n'.allMatches(_textController.text).length + 1;
    });
  }
  
  // 检查是否可以保存
  bool _checkCanSave() {
    return _textController.text.trim().isNotEmpty || _imageList.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialContent);
    _canSave = _checkCanSave();
    
    // 初始化语音识别动画控制器
    _speechAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // 初始化内容行数
    _updateLineCount();
    
    // 解析现有内容中的图片
    _extractImagesFromMarkdown();
    
    // 监听输入变化，更新保存按钮状态和行数
    _textController.addListener(() {
      final canSave = _checkCanSave();
      if (canSave != _canSave) {
        setState(() {
          _canSave = canSave;
        });
      }
      _updateLineCount();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _imageScrollController.dispose();
    _speechAnimationController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  // 从设备选择图片并插入（支持多选）
  Future<void> _pickImage() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFiles.isNotEmpty) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        List<_ImageItem> newImages = [];
        List<String> newMdCodes = [];
        
        // 1. 立即保存到本地并显示，提供即时响应
        for (var pickedFile in pickedFiles) {
          await _saveImageLocally(pickedFile, newImages, newMdCodes);
        }
        
        // 2. 立即更新UI，让用户看到图片
        setState(() {
          _imageList.addAll(newImages);
          _mdCodes.addAll(newMdCodes);
          _canSave = true;
        });
        
        // 移除成功通知，减少干扰用户体验
        
        // 3. 如果已登录且不是本地模式，启动后台上传
        if (appProvider.isLoggedIn && 
            !appProvider.isLocalMode && 
            appProvider.resourceService != null) {
          _uploadImagesInBackground(pickedFiles, newImages);
        }
      }
    } catch (e) {
      if (kDebugMode) print('选择图片失败: $e');
      SnackBarUtils.showError(context, '选择图片失败');
    }
  }
  
  // 后台上传图片到服务器
  Future<void> _uploadImagesInBackground(List<XFile> pickedFiles, List<_ImageItem> localImages) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    try {
      // if (kDebugMode) print('NoteEditor: 开始后台上传 ${pickedFiles.length} 张图片');
      
      // 标记图片为上传中状态
      setState(() {
        for (int i = 0; i < localImages.length; i++) {
          final index = _imageList.indexOf(localImages[i]);
          if (index != -1) {
            _imageList[index] = localImages[i].copyWith(uploadStatus: UploadStatus.uploading);
          }
        }
      });
      
      List<File> imageFiles = [];
      for (var xfile in pickedFiles) {
        imageFiles.add(File(xfile.path));
      }
      
      final uploadResults = await appProvider.resourceService!.uploadImages(imageFiles);
      print('NoteEditor: 获得上传结果，共 ${uploadResults.length} 个结果');
      int successCount = 0;
      
      for (int i = 0; i < uploadResults.length; i++) {
        final result = uploadResults[i];
        final localImage = localImages[i];
        
        print('NoteEditor: 处理第${i}张图片结果: $result');
        print('NoteEditor: 寻找本地图片: ${localImage.path}');
        
        // 通过路径找到对应的图片索引，而不是通过对象引用
        int localImageIndex = -1;
        for (int j = 0; j < _imageList.length; j++) {
          if (_imageList[j].path == localImage.path) {
            localImageIndex = j;
            break;
          }
        }
        
        print('NoteEditor: 本地图片索引: $localImageIndex');
        
        if (localImageIndex == -1) {
          print('NoteEditor: 在_imageList中未找到对应图片，尝试按文件名匹配');
          // 如果按完整路径找不到，尝试按文件名匹配
          final localFileName = path.basename(localImage.path);
          for (int j = 0; j < _imageList.length; j++) {
            final fileName = path.basename(_imageList[j].path);
            if (fileName == localFileName) {
              localImageIndex = j;
              print('NoteEditor: 通过文件名找到匹配图片，索引: $localImageIndex');
              break;
            }
          }
        }
        
        if (localImageIndex == -1) {
          print('NoteEditor: 完全找不到对应的本地图片，跳过');
          continue; // 图片已被删除
        }
        
        if (result['success'] == true) {
          final resourceUid = result['resourceUid'];
          final serverPath = '/o/r/$resourceUid';
          final localPath = localImage.path;
          
          print('NoteEditor: 准备更新图片路径: $localPath -> $serverPath');
          
          // 更新图片项为服务器路径
          setState(() {
            _imageList[localImageIndex] = localImage.copyWith(
              path: serverPath,
              uploadStatus: UploadStatus.success,
            );
          });
          
          // 替换Markdown中的本地路径为服务器路径
          final localMdPattern = '![图片]($localPath)';
          final serverMdPattern = '![图片]($serverPath)';
          final mdIndex = _mdCodes.indexOf(localMdPattern);
          print('NoteEditor: Markdown替换: $localMdPattern -> $serverMdPattern, 索引: $mdIndex');
          if (mdIndex != -1) {
            setState(() {
              _mdCodes[mdIndex] = serverMdPattern;
            });
          }
          
          // 清除缓存以确保显示最新图片
          _clearImageCache(serverPath);
          
          // 注意：不更新文本编辑器内容，保持图片Markdown隐藏
          
          successCount++;
          print('NoteEditor: 图片 $i 上传成功，路径: $serverPath');
        } else {
          // 上传失败，保持本地路径，标记失败状态
          setState(() {
            _imageList[localImageIndex] = localImage.copyWith(uploadStatus: UploadStatus.failed);
          });
          print('NoteEditor: 图片 $i 上传失败: ${result['error']}');
        }
      }
      
      // 删除上传成功提示，提升用户体验
      // if (successCount > 0) {
      //   SnackBarUtils.showSuccess(context, '成功上传 $successCount 张图片到服务器');
      // }
      
      if (successCount < pickedFiles.length) {
        SnackBarUtils.showError(context, '${pickedFiles.length - successCount} 张图片上传失败');
      }
      
    } catch (e, stackTrace) {
      print('NoteEditor: 后台上传异常: $e');
      print('NoteEditor: 异常堆栈: $stackTrace');
      // 标记所有图片为上传失败
      setState(() {
        for (int i = 0; i < localImages.length; i++) {
          final index = _imageList.indexOf(localImages[i]);
          if (index != -1) {
            _imageList[index] = localImages[i].copyWith(uploadStatus: UploadStatus.failed);
          }
        }
      });
    }
  }
  
  // 同步更新文本编辑器内容（已禁用，保持图片Markdown隐藏）
  void _updateTextContent() {
    // 不再更新文本编辑器内容，避免图片Markdown显示在编辑框中
    // 图片Markdown只在保存时通过 _prepareFinalContent() 添加
  }
  
  // 清除图片缓存
  void _clearImageCache(String imagePath) {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.resourceService != null && imagePath.startsWith('/o/r/')) {
        final fullUrl = appProvider.resourceService!.buildImageUrl(imagePath);
        // 清除CachedNetworkImage的缓存
        CachedNetworkImage.evictFromCache(fullUrl);
        print('NoteEditor: 已清除图片缓存 - $fullUrl');
      }
    } catch (e) {
      print('NoteEditor: 清除缓存失败: $e');
    }
  }
  
  // 构建上传状态指示器
  Widget _buildUploadStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.uploading:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      case UploadStatus.success:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_done,
            color: Colors.white,
            size: 12,
          ),
        );
      case UploadStatus.failed:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 12,
          ),
        );
      case UploadStatus.none:
      default:
        return const SizedBox.shrink(); // 不显示任何图标
    }
  }
  
  // 保存图片到本地的辅助方法
  Future<void> _saveImageLocally(XFile pickedFile, List<_ImageItem> newImages, List<String> newMdCodes) async {
    // 获取应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    
    // 确保图片目录存在
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'image_${timestamp}_${path.basename(pickedFile.path)}';
    final localImagePath = '${imagesDir.path}/$fileName';
    
    // 复制图片到应用目录
    await File(pickedFile.path).copy(localImagePath);
    
    // 添加到列表
    final mdCode = '![图片](file://$localImagePath)';
    newImages.add(_ImageItem(path: 'file://$localImagePath', alt: '图片'));
    newMdCodes.add(mdCode);
  }

  // 解析文本中的引用内容，获取被引用的笔记ID列表
  List<String> _parseReferencesFromText(String content) {
    final List<String> referencedIds = [];
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 匹配 [引用内容] 格式
    final RegExp referenceRegex = RegExp(r'\[([^\]]+)\]');
    final matches = referenceRegex.allMatches(content);
    
    for (var match in matches) {
      final referenceContent = match.group(1);
      if (referenceContent != null && referenceContent.isNotEmpty) {
        if (kDebugMode) {
          print('NoteEditor: 解析到引用内容: "$referenceContent"');
          // 查找匹配的笔记内容
        }
        
        // 查找匹配这个内容的笔记
        final matchingNote = appProvider.notes.firstWhere(
          (note) => note.content.trim() == referenceContent.trim(),
          orElse: () => Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );
        
        if (matchingNote.id.isNotEmpty && !referencedIds.contains(matchingNote.id)) {
          referencedIds.add(matchingNote.id);
          if (kDebugMode) {
            print('NoteEditor: 找到匹配的笔记 ID: ${matchingNote.id}');
          }
        } else {
          if (kDebugMode) {
            print('NoteEditor: 没有找到匹配内容 "$referenceContent" 的笔记');
          }
        }
      }
    }
    
    return referencedIds;
  }



  // 保存后处理引用关系（支持离线）
  Future<void> _syncReferencesAfterSave(String content) async {
    if (widget.currentNoteId == null) return;
    
    try {
      final localRefService = LocalReferenceService.instance;
      
      if (kDebugMode) {
        print('NoteEditor: 保存后处理引用关系');
      }
      
      // 解析文本中的引用并创建本地关系
      final createdCount = await localRefService.parseAndCreateReferences(
        widget.currentNoteId!,
        content,
      );
      
      if (kDebugMode && createdCount > 0) {
        print('NoteEditor: 创建了 $createdCount 个本地引用关系');
      }
      
    } catch (e) {
      if (kDebugMode) print('NoteEditor: 处理引用关系失败: $e');
    }
  }

  // 创建单个引用关系
  Future<void> _createReferenceRelation(String currentNoteId, String relatedMemoId, String baseUrl, String token) async {
    try {
      final url = '$baseUrl/api/v1/memo/$currentNoteId/relation';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      final body = {
        'relatedMemoId': int.parse(relatedMemoId),
        'type': 'REFERENCE',
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (kDebugMode) {
        print('NoteEditor: 创建引用关系 $currentNoteId -> $relatedMemoId, 状态: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('NoteEditor: 创建引用关系失败: $e');
    }
  }

  // 用于保存笔记前的最终内容准备
  String _prepareFinalContent() {
    // 保存前将隐藏的图片Markdown添加回文本
    String finalContent = _textController.text.trim();
    
    // 如果有图片，添加到内容末尾
    if (_imageList.isNotEmpty) {
      // 如果文本非空且没有以换行符结尾，添加换行符
      if (finalContent.isNotEmpty && !finalContent.endsWith('\n')) {
        finalContent += '\n';
      }
      
      // 添加所有图片的Markdown代码
      for (var i = 0; i < _imageList.length; i++) {
        var img = _imageList[i];
        var mdCode = i < _mdCodes.length ? 
            _mdCodes[i] : 
            '![${img.alt}](${img.path})';
        finalContent += mdCode + '\n';
      }
    }
    
    return finalContent.trim();
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸和键盘高度
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    // 基础编辑框高度 - 屏幕高度的35%或300像素，取较大值
    final baseEditorHeight = math.max(screenSize.height * 0.35, 300.0);
    
    // 计算编辑区域的自适应高度（根据行数）
    final contentHeight = math.min(
      _lineCount * _singleLineHeight, // 根据行数计算高度
      _maxLines * _singleLineHeight,  // 最大高度（10行）
    );
    
    // 底部工具栏高度
    const toolbarHeight = 50.0;
    
    // 顶部指示器和内边距高度
    const topElementsHeight = 20.0;
    
    // 图片预览区域高度
    final imagePreviewHeight = _imageList.isEmpty ? 0.0 : 120.0;
    
    // 编辑器总高度 = 内容高度 + 工具栏高度 + 顶部元素高度 + 图片预览高度
    final editorHeight = math.max(
      contentHeight + toolbarHeight + topElementsHeight + imagePreviewHeight + 32, // 添加额外padding空间
      baseEditorHeight
    );
    
    // 获取当前主题模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? (Colors.grey[600] ?? Colors.grey) : (Colors.grey[800] ?? Colors.grey);
    final iconColor = isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor;
    final dividerColor = isDarkMode ? Colors.grey[800] ?? Colors.grey.shade800 : Colors.grey[200] ?? Colors.grey.shade200;
    final hintTextColor = isDarkMode ? Colors.grey[600] : Colors.grey[400];
    
    // 确保即使只有图片也能保存
    bool canSave = _textController.text.trim().isNotEmpty || _imageList.isNotEmpty;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      // 点击空白区域关闭编辑框
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // 确保内容位于底部
            children: [
              // 编辑器主体 - 使用GestureDetector拦截点击事件
              GestureDetector(
                onTap: () {}, // 空的onTap阻止点击事件冒泡
                child: Container(
                  height: editorHeight,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 顶部灰条 - 类似于iOS的拖动指示器
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // 编辑区域 - 高度自适应，支持滚动
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(left: 16, right: 56, top: 8, bottom: 8),
                              child: TextField(
                                controller: _textController,
                                scrollController: _scrollController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null, // 允许无限行
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: '现在的想法是...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    color: hintTextColor,
                                    height: 1.5,
                                  ),
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                                cursorColor: iconColor,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            
                            // 语音识别按钮 - 固定在右上角
                            Positioned(
                              top: 4,
                              right: 12,
                              child: _buildSpeechButton(iconColor, secondaryTextColor),
                            ),
                            
                            // 实时识别文本提示 - 大厂级别的炫酷动效
                          if (_isSpeechListening)
                            Positioned(
                              bottom: 8,
                              left: 16,
                              right: 56,
                              child: GestureDetector(
                                onTap: _toggleSpeechRecognition, // 点击整个识别框停止
                                behavior: HitTestBehavior.opaque, // 确保整个区域可点击
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _partialSpeechText.isEmpty 
                                          ? [iconColor.withOpacity(0.05), iconColor.withOpacity(0.1)]
                                          : [iconColor.withOpacity(0.12), iconColor.withOpacity(0.18)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: iconColor.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: iconColor.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          // 音波动画
                                          _buildSoundWaveAnimation(iconColor),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // 状态文字
                                                Text(
                                                  _partialSpeechText.isEmpty ? '正在聆听...' : '识别中',
                                                  style: TextStyle(
                                                    color: iconColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (_partialSpeechText.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  // 识别文字 - 带打字机效果
                                                  AnimatedDefaultTextStyle(
                                                    duration: const Duration(milliseconds: 150),
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      height: 1.4,
                                                    ),
                                                    child: Text(
                                                      _partialSpeechText,
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // 点击停止提示
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: iconColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '点击停止',
                                              style: TextStyle(
                                                color: iconColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
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
                          ],
                        ),
                      ),
                      
                      // 图片预览区域 - 水平滚动
                      if (_imageList.isNotEmpty)
                        Container(
                          height: 110,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: dividerColor, width: 0.5),
                            ),
                          ),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            controller: _imageScrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _imageList.length,
                            itemBuilder: (context, index) {
                              return _buildImagePreviewItem(_imageList[index], index);
                            },
                          ),
                        ),
                      
                      // 更多选项栏（条件显示）
                      if (_showingMoreOptions)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: dividerColor.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            height: 50,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  
                                  // 下划线
                                  _buildMoreOptionButton(
                                    icon: Icons.format_underlined,
                                    onPressed: () {
                                      _wrapSelectedText('<u>', '</u>');
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  // 链接
                                  _buildMoreOptionButton(
                                    icon: Icons.link,
                                    onPressed: () {
                                      _insertText('[链接文本](链接地址)');
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  // 引用格式
                                  _buildMoreOptionButton(
                                    icon: Icons.format_quote,
                                    onPressed: () {
                                      _insertText('\n> ');
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  // 标题
                                  _buildMoreOptionButton(
                                    icon: Icons.title,
                                    onPressed: () {
                                      _insertText('\n# ');
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  // 代码
                                  _buildMoreOptionButton(
                                    icon: Icons.code,
                                    onPressed: () {
                                      _wrapSelectedText('`', '`');
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  // 笔记引用（使用@图标）
                                  _buildMoreOptionButton(
                                    icon: Icons.alternate_email,
                                    onPressed: () {
                                      _showNoteReferenceDialog();
                                      setState(() => _showingMoreOptions = false);
                                    },
                                    secondaryTextColor: secondaryTextColor,
                                  ),
                                  
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // 底部功能栏和发送按钮
                      Container(
                        height: toolbarHeight,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          border: Border(
                            top: BorderSide(color: dividerColor, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            // 功能按钮容器
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 12),
                                    
                                    // # 标签按钮
                                    IconButton(
                                      icon: Text(
                                        '#',
                                        style: TextStyle(
                                          fontSize: 20, 
                                          fontWeight: FontWeight.bold,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      onPressed: () => _insertText('#'),
                                      iconSize: 20,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    
                                    // 图片按钮
                                    IconButton(
                                      icon: Icon(Icons.photo_outlined, 
                                          size: 20, 
                                          color: secondaryTextColor),
                                      onPressed: _pickImage,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    
                                    // B 粗体按钮
                                    IconButton(
                                      icon: Text(
                                        'B',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      onPressed: () => _wrapSelectedText('**', '**'),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    
                                    // 列表按钮
                                    IconButton(
                                      icon: Icon(Icons.format_list_bulleted, 
                                          size: 20, 
                                          color: secondaryTextColor),
                                      onPressed: () => _insertText('\n- '),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    
                                    // 更多按钮
                                    IconButton(
                                      icon: Icon(_showingMoreOptions ? Icons.keyboard_arrow_down : Icons.more_horiz, 
                                          size: 20, 
                                          color: secondaryTextColor),
                                      onPressed: _showMoreOptions,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // 发送按钮
                            Container(
                              padding: const EdgeInsets.only(right: 12),
                              child: Container(
                                width: 70,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: canSave 
                                    ? (isDarkMode ? AppTheme.primaryLightColor : AppTheme.primaryColor) 
                                    : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: (canSave && !_isSaving)
                                      ? () async {
                                          if (_isSaving) return;
                                          
                                          setState(() {
                                            _isSaving = true;
                                          });
                                          
                                          try {
                                            print('NoteEditor: 开始保存笔记...');
                                            
                                            // 准备最终内容
                                            String finalContent = _prepareFinalContent();
                                            
                                            // 如果内容为空且没有图片，不保存
                                            if (finalContent.isEmpty && _imageList.isEmpty) {
                                              setState(() {
                                                _isSaving = false;
                                              });
                                              return;
                                            }
                                            
                                            await widget.onSave(finalContent);
                                            print('NoteEditor: 笔记保存成功，准备关闭编辑器');
                                            
                                            // 使用安全的方式关闭编辑器
                                            if (mounted) {
                                              try {
                                                Navigator.pop(context);
                                                print('NoteEditor: 编辑器已关闭');
                                              } catch (e) {
                                                print('NoteEditor: 关闭编辑器失败: $e');
                                              }
                                            }
                                          } catch (e) {
                                            print('NoteEditor: 保存笔记时出错: $e');
                                            if (mounted) {
                                              SnackBarUtils.showError(context, '保存失败: $e');
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _isSaving = false;
                                              });
                                            }
                                          }
                                        }
                                      : null,
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
            ],
          ),
        ),
      ),
    );
  }
  
  // 构建单个图片预览项
  Widget _buildImagePreviewItem(_ImageItem image, int index) {
    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: _buildImageWidget(image.path),
          ),
          
          // 上传状态指示器
          Positioned(
            top: 2,
            left: 2,
            child: _buildUploadStatusIcon(_imageList[index].uploadStatus),
          ),
          
          // 删除按钮
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 删除图片
  void _removeImage(int index) {
    setState(() {
      if (index < _imageList.length) {
        _imageList.removeAt(index);
        
        if (index < _mdCodes.length) {
          _mdCodes.removeAt(index);
        }
      }
    });
  }
  
  // 在当前光标位置插入文本
  void _insertText(String text) {
    final currentText = _textController.text;
    final selection = _textController.selection;
    final newText = currentText.substring(0, selection.start) + 
                    text + 
                    currentText.substring(selection.end);
    
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + text.length,
      ),
    );
  }
  
  // 用指定的标记包裹所选文本
  void _wrapSelectedText(String prefix, String suffix) {
    final currentText = _textController.text;
    final selection = _textController.selection;
    
    // 如果没有选择文本，插入标记并将光标放在中间
    if (selection.start == selection.end) {
      final newText = currentText.substring(0, selection.start) + 
                      prefix + suffix + 
                      currentText.substring(selection.end);
      
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length,
        ),
      );
    } else {
      // 如果选择了文本，用标记包裹它
      final selectedText = currentText.substring(selection.start, selection.end);
      final newText = currentText.substring(0, selection.start) + 
                      prefix + selectedText + suffix + 
                      currentText.substring(selection.end);
      
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    }
  }
  
  // 构建图片Widget，处理认证问题
  Widget _buildImageWidget(String uriString) {
    print('NoteEditor: 构建图片组件 - 路径: $uriString');
    
    if (uriString.startsWith('/o/r/')) {
      // Memos服务器资源路径，需要认证
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.resourceService != null) {
        final fullUrl = appProvider.resourceService!.buildImageUrl(uriString);
        final token = appProvider.user?.token;
        print('NoteEditor: 使用CachedNetworkImage加载 - URL: $fullUrl, 有Token: ${token != null}');
        
        return CachedNetworkImage(
          imageUrl: fullUrl,
          fit: BoxFit.cover,
          httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
          placeholder: (context, url) {
            print('NoteEditor: 图片加载中 - $url');
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorWidget: (context, url, error) {
            print('NoteEditor: CachedNetworkImage加载失败 - URL: $url, 错误: $error');
            return Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, color: Colors.grey),
                  Text('加载失败', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ],
              ),
            );
          },
        );
      }
    }
    
    // 其他情况使用常规Image
    return Image(
      image: _getImageProvider(uriString),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Image error for $uriString: $error');
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  // 根据URI获取适当的ImageProvider
  ImageProvider _getImageProvider(String uriString) {
    try {
      if (uriString.startsWith('http://') || uriString.startsWith('https://')) {
        // 网络图片
        return NetworkImage(uriString);
      } else if (uriString.startsWith('/o/r/')) {
        // Memos服务器资源路径，构建完整URL并添加认证头
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.resourceService != null) {
          final fullUrl = appProvider.resourceService!.buildImageUrl(uriString);
          final token = appProvider.user?.token;
          print('NoteEditor: 加载Memos图片 - URL: $fullUrl, 有Token: ${token != null}');
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
            print('NoteEditor: 加载Memos图片(fallback) - URL: $fullUrl, 有Token: ${token != null}');
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
        // 尝试作为本地文件处理
        try {
          return FileImage(File(uriString));
        } catch (e) {
          print('Error loading image: $e for $uriString');
          // 默认使用资源图片
          return const AssetImage('assets/images/logo.png');
        }
      }
    } catch (e) {
      print('Error in _getImageProvider: $e');
      return const AssetImage('assets/images/logo.png');
    }
  }
  
  // 显示更多Markdown选项
  // 显示笔记引用对话框
  void _showNoteReferenceDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // 过滤掉当前正在编辑的笔记
    final allNotes = appProvider.notes.where((note) => note.id != widget.currentNoteId).toList();
    
    showDialog(
      context: context,
      builder: (context) => _NoteReferenceDialog(
        isDarkMode: isDarkMode,
        allNotes: allNotes,
        onReferenceSelected: (noteId) {
                Navigator.pop(context);
          _addNoteReference(noteId);
        },
      ),
    );
  }

  // 添加笔记引用关系（支持离线）
  Future<void> _addNoteReference(String relatedMemoId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final localRefService = LocalReferenceService.instance;
      
      // 找到被引用的笔记
      final referencedNote = appProvider.notes.firstWhere(
        (note) => note.id.toString() == relatedMemoId.toString(),
        orElse: () => Note(id: '', content: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      
      if (referencedNote.id.isEmpty) {
        SnackBarUtils.showError(context, '找不到要引用的笔记');
        return;
      }
      
      // 在编辑器中插入引用内容
      final referenceText = '[${referencedNote.content}]';
      _insertText(referenceText);
      
      // 如果是新笔记（没有currentNoteId），只插入内容，保存时再建立关系
      if (widget.currentNoteId == null) {
        SnackBarUtils.showInfo(context, '引用内容已插入，保存笔记后将自动建立引用关系');
        return;
      }
      
      // 创建本地引用关系
      final success = await localRefService.createReference(
        widget.currentNoteId!,
        relatedMemoId,
      );
      
      if (success) {
        SnackBarUtils.showSuccess(context, '引用关系已创建');
        
        // 如果是在线模式，尝试后台同步到服务器
        if (appProvider.isLoggedIn && !appProvider.isLocalMode) {
          _syncReferenceToServer(widget.currentNoteId!, relatedMemoId);
        }
      } else {
        SnackBarUtils.showError(context, '创建引用关系失败');
      }
      
    } catch (e) {
      if (kDebugMode) print('Error adding note reference: $e');
      SnackBarUtils.showError(context, '引用失败：$e');
    }
  }
  
  // 同步引用关系到服务器（后台执行，不阻塞UI）
  Future<void> _syncReferenceToServer(String fromNoteId, String toNoteId) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (!appProvider.isLoggedIn || appProvider.memosApiService == null) return;
      
      if (kDebugMode) {
        print('NoteEditor: 后台同步引用关系到服务器 $fromNoteId -> $toNoteId');
      }
      
      // 调用AppProvider的引用关系处理方法
      // 这会在保存笔记时自动处理引用关系同步
      
    } catch (e) {
      if (kDebugMode) {
        print('NoteEditor: 后台同步引用关系失败: $e');
      }
      // 不显示错误信息，因为本地引用关系已经创建成功
    }
  }

  void _showMoreOptions() {
    setState(() {
      _showingMoreOptions = !_showingMoreOptions;
    });
  }
  
  // 防止重复点击的标志
  bool _isProcessing = false;
  
  // 重启连续识别
  Future<void> _restartContinuousRecognition() async {
    if (!_isSpeechListening || !_continuousMode || !mounted) return;
    
    print('NoteEditor: 🔄 准备重启识别...');
    
    // 先确保完全停止
    await _speechService.stopListening();
    
    // 等待系统释放资源
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!_isSpeechListening || !mounted) return;
    
    print('NoteEditor: 🔄 重启识别');
    _startRecognition();
  }
  
  // 启动识别（可重用）
  Future<void> _startRecognition() async {
    final success = await _speechService.startListening(
      context: context,
      onResult: (text) async {
        print('NoteEditor: 收到识别结果 - "$text"');
        
        if (text.isNotEmpty && mounted) {
          _insertText(text);
          // 去掉成功通知，保持流畅体验
          setState(() {
            _partialSpeechText = '';
          });
        }
        
        // 连续模式：自动重启
        if (_continuousMode && _isSpeechListening) {
          _restartContinuousRecognition();
        } else {
          setState(() {
            _isSpeechListening = false;
            _partialSpeechText = '';
          });
        }
      },
    );
    
    if (!success) {
      print('NoteEditor: ❌ 启动识别失败');
      if (mounted) {
        setState(() {
          _isSpeechListening = false;
        });
      }
    }
  }
  
  // 开始/停止语音识别
  Future<void> _toggleSpeechRecognition() async {
    // 防止重复点击
    if (_isProcessing) {
      print('NoteEditor: 操作进行中，忽略重复点击');
      return;
    }
    
    _isProcessing = true;
    
    try {
      if (_isSpeechListening) {
        print('NoteEditor: 停止语音识别');
        // 停止语音识别 - 将当前识别的文本插入
        if (_partialSpeechText.isNotEmpty) {
          _insertText(_partialSpeechText);
        }
        
        await _speechService.stopListening();
        setState(() {
          _isSpeechListening = false;
          _partialSpeechText = '';
        });
      } else {
        print('NoteEditor: 开始语音识别');
      // 开始语音识别
      final hasPermission = await _speechService.checkPermission();
      if (!hasPermission) {
        final granted = await _speechService.requestPermission();
        if (!granted) {
          if (mounted) {
            SnackBarUtils.showError(context, '需要麦克风权限才能使用语音识别');
          }
          return;
        }
      }
      
      // 清空之前的识别结果
      setState(() {
        _partialSpeechText = '';
        _isSpeechListening = true;
      });
      
      // 启动识别
      await _startRecognition();
      }
    } finally {
      // 延迟重置防抖标志
      Future.delayed(const Duration(milliseconds: 500), () {
        _isProcessing = false;
      });
    }
  }

  Widget _buildMoreOptionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color secondaryTextColor,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 20,
        color: secondaryTextColor,
      ),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
  
  // 构建音波动画 - 大厂风格
  Widget _buildSoundWaveAnimation(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: _speechAnimationController,
          builder: (context, child) {
            // 每个条延迟不同的相位，产生波浪效果
            final phase = (index * 0.25);
            final value = math.sin((_speechAnimationController.value * 2 * math.pi) + (phase * 2 * math.pi));
            final height = 8 + (value.abs() * 16); // 8-24之间动态变化
            
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
  
  // 构建语音识别按钮
  Widget _buildSpeechButton(Color iconColor, Color secondaryTextColor) {
    return GestureDetector(
      onTap: _toggleSpeechRecognition,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isSpeechListening 
              ? iconColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: _isSpeechListening
              ? Border.all(color: iconColor.withOpacity(0.3), width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 录音动画波纹效果
            if (_isSpeechListening)
              AnimatedBuilder(
                animation: _speechAnimationController,
                builder: (context, child) {
                  final value = _speechAnimationController.value;
                  return Container(
                    width: 36 + (value * 12),
                    height: 36 + (value * 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withOpacity(0.3 * (1 - value)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            
            // 麦克风图标
            Icon(
              _isSpeechListening ? Icons.mic : Icons.mic_none,
              size: 20,
              color: _isSpeechListening ? iconColor : secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

// 笔记引用对话框
class _NoteReferenceDialog extends StatefulWidget {
  final bool isDarkMode;
  final List<Note> allNotes;
  final Function(String) onReferenceSelected;

  const _NoteReferenceDialog({
    required this.isDarkMode,
    required this.allNotes,
    required this.onReferenceSelected,
  });

  @override
  State<_NoteReferenceDialog> createState() => _NoteReferenceDialogState();
}

class _NoteReferenceDialogState extends State<_NoteReferenceDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Note> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _filteredNotes = widget.allNotes;
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = widget.allNotes;
      } else {
        _filteredNotes = widget.allNotes.where((note) {
          return note.content.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? AppTheme.darkCardColor : Colors.white,
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
                    "添加笔记引用",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: widget.isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择要引用的笔记，建立笔记间的关联关系',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: (widget.isDarkMode ? Colors.white : AppTheme.textPrimaryColor).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索笔记内容...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: widget.isDarkMode 
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                ),
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
            ),
            
            // 笔记列表
            Container(
              constraints: const BoxConstraints(maxHeight: 350),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _filteredNotes.isEmpty
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
                            widget.allNotes.isEmpty ? Icons.note_outlined : Icons.search_off,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.allNotes.isEmpty ? '暂无笔记可引用' : '没有找到相关笔记',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.allNotes.isEmpty 
                            ? '先创建一些笔记再来建立引用关系'
                            : '试试其他关键词',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '找到 ${_filteredNotes.length} 个笔记',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            final preview = note.content.length > 40 
                              ? '${note.content.substring(0, 40)}...'
                              : note.content;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => widget.onReferenceSelected(note.id),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode 
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
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
                                                color: widget.isDarkMode 
                                                  ? AppTheme.darkTextPrimaryColor 
                                                  : AppTheme.textPrimaryColor,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: (widget.isDarkMode 
                                                  ? AppTheme.darkTextSecondaryColor 
                                                  : AppTheme.textSecondaryColor).withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.add_link,
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
                    ],
                  ),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: widget.isDarkMode 
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '取消',
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
    );
  }
}

// 上传状态枚举
enum UploadStatus {
  none,      // 无状态（本地图片）
  uploading, // 上传中
  success,   // 上传成功
  failed,    // 上传失败
}

// 图片项类
class _ImageItem {
  final String path;
  final String alt;
  final UploadStatus uploadStatus;
  
  _ImageItem({
    required this.path, 
    required this.alt,
    this.uploadStatus = UploadStatus.none,
  });
  
  // 复制方法，用于更新状态
  _ImageItem copyWith({
    String? path,
    String? alt,
    UploadStatus? uploadStatus,
  }) {
    return _ImageItem(
      path: path ?? this.path,
      alt: alt ?? this.alt,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }
} 