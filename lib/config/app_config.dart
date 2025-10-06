/// 应用配置中心
/// 统一管理所有API地址、版本信息、反馈地址等配置信息
class AppConfig {
  // ==================== 应用基本信息 ====================
  
  /// 应用名称
  static const String appName = 'InkRoot';
  
  /// 应用版本
  static const String appVersion = '1.0.3';
  
  /// 应用ID (用于云验证等服务)
  static const String appId = '10002';
  
  /// 应用密钥 (用于云验证等服务)
  static const String appKey = 'RLu4EGglybXSgRzK';
  
  /// 应用包名
  static const String packageName = 'com.didichou.inkroot';
  
  // ==================== 官方服务器配置 ====================
  
  /// 官方Memos服务器地址
  static const String officialMemosServer = 'https://memos.didichou.site';
  
  /// API基础地址
  static const String apiBaseUrl = 'https://api.didichou.site';
  
  /// 云验证API地址
  static const String cloudVerificationUrl = '$apiBaseUrl/api.php';
  
  /// 应用更新检查地址
  static const String appUpdateUrl = '$apiBaseUrl/admin/applist.php';
  
  // ==================== 反馈与支持 ====================
  
  /// 反馈邮箱
  static const String supportEmail = 'sdwxgzh@126.com';
  
  /// 官方网站
  static const String officialWebsite = 'https://inkroot.cn/';
  
  /// 用户反馈地址
  static const String feedbackUrl = '$apiBaseUrl/feedback';
  
  /// 帮助文档地址
  static const String helpDocUrl = '$officialWebsite/help';
  
  // ==================== 社交媒体与联系方式 ====================
  
  /// 官方QQ群
  static const String officialQQGroup = '123456789';
  
  /// 官方微信群二维码
  static const String wechatGroupQR = '$apiBaseUrl/images/wechat_group.png';
  
  /// GitHub仓库地址
  static const String githubRepo = 'https://github.com/yyyyymmmmm/IntRoot';
  
  /// Telegram Bot地址
  static const String telegramBotUrl = 'https://t.me/InkRoot_Bot';
  
  // ==================== 法律文档 ====================
  
  /// 隐私政策地址
  static const String privacyPolicyUrl = '$officialWebsite/privacy';
  
  /// 用户协议地址
  static const String userAgreementUrl = '$officialWebsite/terms';
  
  /// 开源协议地址
  static const String licenseUrl = '$githubRepo/blob/main/LICENSE';
  
  // ==================== 企业信息与备案 ====================
  
  /// 公司名称
  static const String companyName = 'InkRoot';
  
  /// 公司全称
  static const String companyFullName = 'InkRoot-墨鸣笔记';
  
  /// 公司地址
  static const String companyAddress = '陕西省西安市雁塔区';
  
  /// 社会信用代码
  static const String socialCreditCode = ''; // 待填写
  
  /// ICP备案号
  static const String icpLicense = '陕ICP备 20002445号-7A';
  
  /// 网络文化经营许可证（如果需要）
  static const String cultureLicense = '';
  
  /// 增值电信业务经营许可证（如果需要）
  static const String telecomLicense = '';
  
  /// 版权年份
  static const String copyrightYear = '2025';
  
  /// 版权声明
  static const String copyrightText = '© $copyrightYear $companyName';
  
  // ==================== 应用商店信息 ====================
  
  /// App Store ID（iOS）
  static const String appStoreId = '';
  
  /// Google Play包名（Android）
  static const String googlePlayPackage = packageName;
  
  /// 华为应用市场包名
  static const String huaweiAppGalleryPackage = packageName;
  
  /// 小米应用商店包名
  static const String xiaomiAppStorePackage = packageName;
  
  // ==================== 功能配置 ====================
  
  /// 是否启用云验证
  static const bool enableCloudVerification = true;
  
  /// 是否启用自动更新检查
  static const bool enableAutoUpdate = true;
  
  /// 是否启用崩溃报告
  static const bool enableCrashReporting = true;
  
  /// 是否启用用户行为分析
  static const bool enableAnalytics = false;
  
  // ==================== 调试配置 ====================
  
  /// 是否启用调试模式
  static const bool debugMode = false;
  
  /// 是否启用详细日志
  static const bool verboseLogging = false;
  
  /// 是否启用网络请求日志
  static const bool enableNetworkLogging = false;
  
  // ==================== 工具方法 ====================
  
  /// 获取完整的版权信息
  static String getFullCopyrightInfo() {
    return '$copyrightText\n$companyFullName\n$icpLicense';
  }
  
  /// 获取云公告URL
  static String getCloudNoticeUrl() {
    return '$apiBaseUrl/notice.php';
  }
  
  /// 获取完整版本信息
  static String getFullVersionInfo() {
    return '$appVersion (Build $packageName)';
  }
  
  /// 获取应用信息映射
  static Map<String, String> getAppInfo() {
    return {
      'appName': appName,
      'appVersion': appVersion,
      'packageName': packageName,
      'companyName': companyName,
      'companyFullName': companyFullName,
      'companyAddress': companyAddress,
      'socialCreditCode': socialCreditCode,
      'icpLicense': icpLicense,
      'cultureLicense': cultureLicense,
      'telecomLicense': telecomLicense,
      'copyrightYear': copyrightYear,
      'copyrightText': copyrightText,
    };
  }
  
  /// 获取许可证信息
  static Map<String, String> getLicenseInfo() {
    final Map<String, String> licenses = {};
    if (icpLicense.isNotEmpty) licenses['ICP备案'] = icpLicense;
    if (cultureLicense.isNotEmpty) licenses['网络文化经营许可证'] = cultureLicense;
    if (telecomLicense.isNotEmpty) licenses['增值电信业务经营许可证'] = telecomLicense;
    return licenses;
  }
  
  /// 检查是否有许可证信息
  static bool hasLicenseInfo() {
    return icpLicense.isNotEmpty || cultureLicense.isNotEmpty || telecomLicense.isNotEmpty;
  }
  
  /// 获取应用标识
  static String getAppIdentifier() {
    return '$appName v$appVersion ($packageName)';
  }
  
  /// 获取构建信息
  static String getBuildInfo() {
    return 'Build: $appVersion | Package: $packageName | Company: $companyName';
  }
}