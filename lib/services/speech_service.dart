import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'simple_permission_service.dart';

/// 语音识别服务
/// 提供离线语音转文字功能
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  late stt.SpeechToText _speech;
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';
  
  /// 获取是否正在监听
  bool get isListening => _isListening;
  
  /// 获取是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 获取最后识别的文本
  String get lastRecognizedText => _lastRecognizedText;

  /// 初始化语音识别服务
  Future<bool> initialize() async {
    if (kDebugMode) {
      print('🎤 [SpeechService] 初始化语音识别服务');
    }
    
    try {
      _speech = stt.SpeechToText();
      _isInitialized = await _speech.initialize(
        onError: (error) {
          if (kDebugMode) {
            print('🎤 [SpeechService] 错误: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          if (kDebugMode) {
            print('🎤 [SpeechService] 状态: $status');
          }
          _isListening = status == 'listening';
        },
      );
      
      if (kDebugMode) {
        print('🎤 [SpeechService] 初始化${_isInitialized ? "成功" : "失败"}');
      }
      
      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('🎤 [SpeechService] 初始化异常: $e');
      }
      _isInitialized = false;
      return false;
    }
  }

  /// 检查麦克风权限
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 检查权限（兼容性方法）
  Future<bool> checkPermission() async {
    return await checkMicrophonePermission();
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 请求权限（兼容性方法）
  Future<bool> requestPermission() async {
    return await requestMicrophonePermission();
  }

  /// 开始语音识别
  Future<bool> startListening({
    Function(String)? onResult,
    Function(String)? onError,
    Duration? timeout,
    BuildContext? context,
  }) async {
    try {
      // iOS: speech_to_text的initialize()方法会自动触发权限请求
      // 所以不需要提前请求权限，直接初始化即可
      if (!_isInitialized) {
        if (kDebugMode) {
          print('🎤 [SpeechService] 开始初始化（这会触发iOS权限请求）');
        }
        
        // 在iOS上，这个调用会触发麦克风和语音识别权限请求
        final success = await initialize();
        
        if (!success) {
          if (kDebugMode) {
            print('🎤 [SpeechService] 初始化失败，可能是权限被拒绝');
          }
          
          // 如果初始化失败，引导用户到设置
          if (context != null) {
            _showPermissionDeniedDialog(context);
          }
          return false;
        }
      }
      
      if (!_isInitialized) {
        if (kDebugMode) {
          print('🎤 [SpeechService] 未初始化，无法开始识别');
        }
        return false;
      }

      // 检查权限状态
      final available = await _speech.hasPermission;
      if (!available) {
        if (kDebugMode) {
          print('🎤 [SpeechService] 权限检查失败，引导用户到设置');
        }
        
        if (context != null) {
          _showPermissionDeniedDialog(context);
        }
        return false;
      }

      await _speech.listen(
        onResult: (result) {
          _lastRecognizedText = result.recognizedWords;
          if (onResult != null && result.finalResult) {
            onResult(_lastRecognizedText);
          }
        },
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'zh_CN',
        onSoundLevelChange: null,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      _isListening = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🎤 [SpeechService] 开始识别失败: $e');
      }
      if (onError != null) {
        onError(e.toString());
      }
      return false;
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      if (kDebugMode) {
        print('🎤 [SpeechService] 停止语音识别');
      }
    }
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      _lastRecognizedText = '';
      if (kDebugMode) {
        print('🎤 [SpeechService] 取消语音识别');
      }
    }
  }

  /// 获取支持的语言列表
  Future<List<String>> getSupportedLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isInitialized) {
      final locales = await _speech.locales();
      return locales.map((locale) => locale.localeId).toList();
    }
    return ['zh-CN', 'en-US'];
  }

  /// 检查设备是否支持语音识别
  Future<bool> isDeviceSupported() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  /// 测试语音权限和功能
  Future<Map<String, dynamic>> testSpeechCapabilities() async {
    final result = <String, dynamic>{};
    
    try {
      // 1. 检查初始化状态
      if (!_isInitialized) {
        await initialize();
      }
      result['initialized'] = _isInitialized;
      
      // 2. 检查设备支持
      final deviceSupported = await _speech.hasPermission;
      result['deviceSupported'] = deviceSupported;
      
      // 3. 检查权限状态
      if (Platform.isIOS) {
        final micStatus = await Permission.microphone.status;
        final speechStatus = await Permission.speech.status;
        result['microphonePermission'] = micStatus.toString();
        result['speechPermission'] = speechStatus.toString();
      }
      
      // 4. 获取可用语言
      final locales = await _speech.locales();
      result['availableLocales'] = locales.map((l) => l.localeId).toList();
      result['hasChineseSupport'] = locales.any((l) => l.localeId.startsWith('zh'));
      
      // 5. 检查当前状态
      result['isListening'] = _isListening;
      result['lastText'] = _lastRecognizedText;
      
      if (kDebugMode) {
        print('🎤 [SpeechService] 语音功能测试结果:');
        result.forEach((key, value) {
          print('   $key: $value');
        });
      }
      
    } catch (e) {
      result['error'] = e.toString();
      if (kDebugMode) {
        print('🎤 [SpeechService] 测试失败: $e');
      }
    }
    
    return result;
  }

  /// 释放资源
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _isListening = false;
    _lastRecognizedText = '';
    if (kDebugMode) {
      print('🎤 [SpeechService] 释放资源');
    }
  }

  /// 显示权限被拒绝的对话框
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Text('🎤', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('需要麦克风权限'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('语音识别功能需要麦克风和语音识别权限。'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '操作步骤：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 点击"去设置"按钮\n2. 找到"麦克风"和"语音识别"\n3. 开启权限开关\n4. 返回应用重试',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }
}