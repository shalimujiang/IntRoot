import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';

class ImageCacheManager {
  static const String keyAuthImages = 'authImageCache';
  static const String keyNormalImages = 'normalImageCache';

  // 🔥 创建一个宽松的 HTTP 客户端，即使认证失败也返回缓存
  static http.Client _createHttpClient() {
    final ioClient = HttpClient();
    // 允许长时间连接
    ioClient.connectionTimeout = const Duration(seconds: 30);
    return IOClient(ioClient);
  }

  // 认证图片缓存 (90天，2000个对象) - 🔥 更长缓存时间
  static final CacheManager _authImageCacheManager = CacheManager(
    Config(
      keyAuthImages,
      stalePeriod: const Duration(days: 90), // 🔥 90天不过期
      maxNrOfCacheObjects: 2000, // 🔥 支持更多图片
      repo: JsonCacheInfoRepository(databaseName: keyAuthImages),
      fileService: HttpFileService(httpClient: _createHttpClient()),
    ),
  );

  // 普通图片缓存 (30天，1000个对象)
  static final CacheManager _normalImageCacheManager = CacheManager(
    Config(
      keyNormalImages,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: keyNormalImages),
      fileService: HttpFileService(httpClient: _createHttpClient()),
    ),
  );

  static CacheManager get authImageCache => _authImageCacheManager;
  static CacheManager get normalImageCache => _normalImageCacheManager;

  // 清理所有缓存
  static Future<void> clearAllCache() async {
    await _authImageCacheManager.emptyCache();
    await _normalImageCacheManager.emptyCache();
  }

  // 初始化
  static Future<void> initialize() async {
    print('ImageCacheManager initialized');
  }
} 