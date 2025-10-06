import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import '../models/note_model.dart';
import '../providers/app_provider.dart';
import '../themes/app_theme.dart';
import '../utils/share_utils.dart';
import '../utils/snackbar_utils.dart';

class ShareImagePreviewScreen extends StatefulWidget {
  final String noteId;
  final String content;
  final DateTime timestamp;

  const ShareImagePreviewScreen({
    Key? key,
    required this.noteId,
    required this.content,
    required this.timestamp,
  }) : super(key: key);

  @override
  State<ShareImagePreviewScreen> createState() => _ShareImagePreviewScreenState();
}

class _ShareImagePreviewScreenState extends State<ShareImagePreviewScreen> {
  ShareTemplate _currentTemplate = ShareTemplate.simple;
  bool _isGeneratingPreview = false;
  Uint8List? _previewImageBytes;
  
  // 显示控制选项
  bool _showTime = true;
  bool _showUser = true;
  bool _showBrand = true;

  @override
  void initState() {
    super.initState();
    // 确保初始化时设置默认模板
    _currentTemplate = ShareTemplate.simple;
    // 初始化时生成第一个模板的预览
    _generatePreview();
  }

  // 生成预览图
  Future<void> _generatePreview() async {
    setState(() {
      _isGeneratingPreview = true;
    });

    try {
      // 获取图片路径
      final imagePaths = await _getImagePaths();
      
      // 获取baseUrl和token
      final provider = Provider.of<AppProvider>(context, listen: false);
      final baseUrl = provider.resourceService?.baseUrl;
      final token = provider.user?.token;
      
      // 生成预览图
      final imageBytes = await ShareUtils.generatePreviewImage(
        content: widget.content,
        timestamp: widget.timestamp,
        template: _currentTemplate,
        imagePaths: imagePaths,
        baseUrl: baseUrl,
        token: token,
        username: provider.user?.nickname,
        showTime: _showTime,
        showUser: _showUser,
        showBrand: _showBrand,
      );

      setState(() {
        _previewImageBytes = imageBytes;
        _isGeneratingPreview = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingPreview = false;
      });
      // 显示错误提示
      if (mounted) {
        SnackBarUtils.showError(context, '预览生成失败: ${e.toString()}');
      }
    }
  }

  // 获取图片路径
  Future<List<String>> _getImagePaths() async {
    final List<String> imagePaths = [];
    
    // 从现有笔记获取图片资源
    final provider = Provider.of<AppProvider>(context, listen: false);
    final notes = provider.notes;
    final currentNote = notes.firstWhere(
      (note) => note.id == widget.noteId,
      orElse: () => Note(
        id: widget.noteId,
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
    
    return imagePaths;
  }

  // 切换模板
  void _switchTemplate(ShareTemplate template) {
    if (_currentTemplate != template) {
      setState(() {
        _currentTemplate = template;
      });
      _generatePreview();
    }
  }

  // 分享图片
  Future<void> _shareImage() async {
    if (_previewImageBytes == null) {
      SnackBarUtils.showWarning(context, '请等待预览生成完成');
      return;
    }

    try {
      // 获取图片路径
      final imagePaths = await _getImagePaths();
      
      // 获取baseUrl和token
      final provider = Provider.of<AppProvider>(context, listen: false);
      final baseUrl = provider.resourceService?.baseUrl;
      final token = provider.user?.token;
      
      final success = await ShareUtils.generateShareImage(
        context: context,
        content: widget.content,
        timestamp: widget.timestamp,
        template: _currentTemplate,
        imagePaths: imagePaths,
        baseUrl: baseUrl,
        token: token,
        username: provider.user?.nickname,
        showTime: _showTime,
        showUser: _showUser,
        showBrand: _showBrand,
      );
      
      if (!success && mounted) {
        SnackBarUtils.showError(context, '分享失败');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '分享失败: ${e.toString()}');
      }
    }
  }

  // 保存图片
  Future<void> _saveImage() async {
    if (_previewImageBytes == null) {
      SnackBarUtils.showWarning(context, '请等待预览生成完成');
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkCardColor 
              : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在保存图片...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在保存到相册，请稍候',
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
    );

    try {
      // 获取图片路径
      final imagePaths = await _getImagePaths();
      
      // 获取baseUrl和token
      final provider = Provider.of<AppProvider>(context, listen: false);
      final baseUrl = provider.resourceService?.baseUrl;
      final token = provider.user?.token;
      
      final success = await ShareUtils.saveImageToGalleryWithProgress(
        context: context,
        content: widget.content,
        timestamp: widget.timestamp,
        template: _currentTemplate,
        imagePaths: imagePaths,
        baseUrl: baseUrl,
        token: token,
        onProgress: (progress) {
          // 输出详细进度信息（开发调试用）
          if (kDebugMode) {
            final stage = progress <= 0.1 ? '分析阶段' 
                       : progress <= 0.4 ? '加载阶段' 
                       : progress <= 0.8 ? '生成阶段' 
                       : '保存阶段';
            print('保存图片进度: ${(progress * 100).toInt()}% ($stage)');
          }
        },
      );
      
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, '图片已保存到相册');
        } else {
          SnackBarUtils.showError(context, '保存失败，请检查相册权限');
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        // 🔧 优化错误提示 - 区分不同错误类型
        String errorMessage = '保存失败，请重试';
        IconData errorIcon = Icons.error_outline;
        
        if (e.toString().contains('权限') || e.toString().contains('permission')) {
          errorMessage = '需要相册权限，请在设置中允许访问';
          errorIcon = Icons.security;
        } else if (e.toString().contains('空间') || e.toString().contains('storage')) {
          errorMessage = '存储空间不足，请清理后重试';
          errorIcon = Icons.storage;
        } else if (e.toString().contains('网络') || e.toString().contains('network')) {
          errorMessage = '网络异常，请检查网络连接';
          errorIcon = Icons.wifi_off;
        }
        
        SnackBarUtils.showError(context, errorMessage);
      }
      if (kDebugMode) print('Error saving image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '生成分享图',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 优化的预览区域 - 提升滚动体验
          Expanded(
            child: Container(
              width: double.infinity,
              child: _isGeneratingPreview
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '正在生成预览...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _previewImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(), // iOS风格弹性滚动
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.memory(
                                _previewImageBytes!,
                                fit: BoxFit.fitWidth,
                                width: double.infinity,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '预览生成失败',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),

          // 移除初始界面的模板选择区域，只在弹出界面中显示

          // 底部操作栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // 更换模板按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 显示更多模板选项
                      _showMoreTemplateOptions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.grey.shade50,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text('更换模板'),
                  ),
                ),
                const SizedBox(width: 12),
                // 保存图片按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('保存图片'),
                  ),
                ),
                const SizedBox(width: 12),
                // 更多按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _shareImage(); // 暂时用分享功能代替
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.grey.shade50,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text('更多'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建模板选择按钮
  Widget _buildTemplateButton(String title, ShareTemplate template) {
    final isSelected = _currentTemplate == template;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _switchTemplate(template),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 显示更多模板选项 - 底部弹出式
  void _showMoreTemplateOptions() {
    // 使用底部弹出框而不是全屏对话框
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.3, // 控制高度为屏幕的30%，与参考图一致
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // 顶部拖动条
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // 模板网格
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTemplateCardForDialog("简约模板", ShareTemplate.simple, setModalState),
                            const SizedBox(width: 12),
                            _buildTemplateCardForDialog("卡片模板", ShareTemplate.card, setModalState),
                            const SizedBox(width: 12),
                            _buildTemplateCardForDialog("渐变模板", ShareTemplate.gradient, setModalState),
                            const SizedBox(width: 12),
                            _buildTemplateCardForDialog("日记模板", ShareTemplate.diary, setModalState),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 确定按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // 关闭模板选择，回到预览界面
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '确定',
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
            );
          }
        );
      },
    );
  }

  // 为对话框构建模板卡片
  Widget _buildTemplateCardForDialog(String title, ShareTemplate template, StateSetter setModalState) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentTemplate == template;
    
    return GestureDetector(
      onTap: () {
        // 更新对话框中的状态
        setModalState(() {});
        // 更新主页面状态
        setState(() {
          _currentTemplate = template;
        });
        // 重新生成预览
        _generatePreview();
      },
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // 模板预览
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getTemplatePreviewColor(template),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: _getTemplatePreviewContent(template),
                ),
              ),
            ),
            
            // 模板名称和选中标记
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 14,
                    ),
                  if (isSelected)
                    const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : null,
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
  
  // 构建简化版模板卡片（横向滚动版本）
  Widget _buildSimpleTemplateCard(String title, ShareTemplate template) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentTemplate == template;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTemplate = template; // 直接更新当前模板
        });
        _generatePreview(); // 重新生成预览
      },
      child: Container(
        width: 100, // 调整宽度，与参考图一致
        height: 140, // 调整高度，与参考图一致
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // 模板预览
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(6), // 减小边距
                decoration: BoxDecoration(
                  color: _getTemplatePreviewColor(template),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: _getTemplatePreviewContent(template),
                ),
              ),
            ),
            
            // 模板名称和选中标记
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6), // 减小内边距
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 14, // 减小图标大小
                    ),
                  if (isSelected)
                    const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11, // 减小字体大小
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : null,
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
    // 对所有模板使用相同的预览内容样式，只是颜色和背景不同
    final Color primaryColor = _getTemplatePrimaryColor(template);
    final Color backgroundColor = _getTemplatePreviewColor(template);
    
    return Container(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 顶部日期和标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 20,
                height: 4,
                color: primaryColor.withOpacity(0.7),
              ),
              Container(
                width: 15,
                height: 4,
                color: primaryColor.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 内容线条
          Container(
            width: double.infinity,
            height: 3,
            color: primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            height: 3,
            color: primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity * 0.7,
            height: 3,
            color: primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          // 底部信息
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 25,
              height: 3,
              color: primaryColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // 获取模板主色调
  Color _getTemplatePrimaryColor(ShareTemplate template) {
    switch (template) {
      case ShareTemplate.simple:
        return Colors.grey.shade400;
      case ShareTemplate.card:
        return Colors.blue.shade300;
      case ShareTemplate.gradient:
        return Colors.purple.shade300;
      case ShareTemplate.diary:
        return Colors.amber.shade700;
    }
  }

  // 显示选项菜单
  void _showOptionsMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    '显示选项',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 时间显示开关
                  _buildToggleOption(
                    '显示时间',
                    '在分享图片右上角显示时间信息',
                    Icons.access_time,
                    _showTime,
                    (value) {
                      setModalState(() {
                        _showTime = value;
                      });
                      setState(() {
                        _showTime = value;
                      });
                      _generatePreview(); // 重新生成预览
                    },
                    isDarkMode,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 用户名显示开关
                  _buildToggleOption(
                    '显示用户名',
                    '在分享图片左上角显示用户名或InkRoot',
                    Icons.person,
                    _showUser,
                    (value) {
                      setModalState(() {
                        _showUser = value;
                      });
                      setState(() {
                        _showUser = value;
                      });
                      _generatePreview(); // 重新生成预览
                    },
                    isDarkMode,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 品牌信息显示开关
                  _buildToggleOption(
                    '显示版权',
                    '在分享图片右下角显示InkRoot品牌信息',
                    Icons.copyright,
                    _showBrand,
                    (value) {
                      setModalState(() {
                        _showBrand = value;
                      });
                      setState(() {
                        _showBrand = value;
                      });
                      _generatePreview(); // 重新生成预览
                    },
                    isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 关闭按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 构建切换选项组件
  Widget _buildToggleOption(
    String title,
    String description,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 图标
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
          
          // 文本信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // 开关
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

} 