class AppConfig {
  final bool isLocalMode;
  final String? memosApiUrl;
  final String? lastToken;
  final String? lastUsername;
  final String? lastServerUrl;
  final bool rememberLogin;
  final bool autoLogin;
  final bool autoSyncEnabled;
  final int syncInterval;
  final bool isDarkMode; // 保留此字段以兼容旧版本
  final String themeMode; // 主题模式：default(默认), fenglan(凤蓝)
  final String themeSelection; // 主题选择：system(跟随系统)、light(纸白)、dark(幽谷)
  final String defaultNoteVisibility; // 新建笔记的默认可见性

  static const String THEME_SYSTEM = 'system';
  static const String THEME_LIGHT = 'light';
  static const String THEME_DARK = 'dark';
  
  // 笔记可见性选项
  static const String VISIBILITY_PRIVATE = 'PRIVATE';
  static const String VISIBILITY_PUBLIC = 'PUBLIC';

  AppConfig({
    this.isLocalMode = false,
    this.memosApiUrl,
    this.lastToken,
    this.lastUsername,
    this.lastServerUrl,
    this.rememberLogin = false,
    this.autoLogin = false,
    this.autoSyncEnabled = false,
    this.syncInterval = 300,
    this.isDarkMode = false,
    this.themeMode = 'default',
    this.themeSelection = THEME_SYSTEM, // 默认跟随系统
    this.defaultNoteVisibility = VISIBILITY_PRIVATE, // 默认私有
  });

  AppConfig copyWith({
    bool? isLocalMode,
    String? memosApiUrl,
    String? lastToken,
    String? lastUsername,
    String? lastServerUrl,
    bool? rememberLogin,
    bool? autoLogin,
    bool? autoSyncEnabled,
    int? syncInterval,
    bool? isDarkMode,
    String? themeMode,
    String? themeSelection,
    String? defaultNoteVisibility,
  }) {
    return AppConfig(
      isLocalMode: isLocalMode ?? this.isLocalMode,
      memosApiUrl: memosApiUrl ?? this.memosApiUrl,
      lastToken: lastToken ?? this.lastToken,
      lastUsername: lastUsername ?? this.lastUsername,
      lastServerUrl: lastServerUrl ?? this.lastServerUrl,
      rememberLogin: rememberLogin ?? this.rememberLogin,
      autoLogin: autoLogin ?? this.autoLogin,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncInterval: syncInterval ?? this.syncInterval,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      themeMode: themeMode ?? this.themeMode,
      themeSelection: themeSelection ?? this.themeSelection,
      defaultNoteVisibility: defaultNoteVisibility ?? this.defaultNoteVisibility,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLocalMode': isLocalMode,
      'memosApiUrl': memosApiUrl,
      'lastToken': lastToken,
      'lastUsername': lastUsername,
      'lastServerUrl': lastServerUrl,
      'rememberLogin': rememberLogin,
      'autoLogin': autoLogin,
      'autoSyncEnabled': autoSyncEnabled,
      'syncInterval': syncInterval,
      'isDarkMode': isDarkMode,
      'themeMode': themeMode,
      'themeSelection': themeSelection,
      'defaultNoteVisibility': defaultNoteVisibility,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isLocalMode: json['isLocalMode'] ?? false,
      memosApiUrl: json['memosApiUrl'],
      lastToken: json['lastToken'],
      lastUsername: json['lastUsername'],
      lastServerUrl: json['lastServerUrl'],
      rememberLogin: json['rememberLogin'] ?? false,
      autoLogin: json['autoLogin'] ?? false,
      autoSyncEnabled: json['autoSyncEnabled'] ?? false,
      syncInterval: json['syncInterval'] ?? 300,
      isDarkMode: json['isDarkMode'] ?? false,
      themeMode: json['themeMode'] ?? 'default',
      themeSelection: json['themeSelection'] ?? THEME_SYSTEM,
      defaultNoteVisibility: json['defaultNoteVisibility'] ?? VISIBILITY_PRIVATE,
    );
  }
} 