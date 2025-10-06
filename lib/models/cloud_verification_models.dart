/// 星河云验证 - 应用配置响应
class CloudAppConfigResponse {
  final int code;
  final CloudAppConfigData? msg;
  final int time;
  final String check;

  CloudAppConfigResponse({
    required this.code,
    this.msg,
    required this.time,
    required this.check,
  });

  factory CloudAppConfigResponse.fromJson(Map<String, dynamic> json) {
    return CloudAppConfigResponse(
      code: json['code'] ?? 0,
      msg: json['msg'] != null ? CloudAppConfigData.fromJson(json['msg']) : null,
      time: json['time'] ?? 0,
      check: json['check'] ?? '',
    );
  }

  bool get isSuccess => code == 200;
}

/// 星河云验证 - 应用配置数据
class CloudAppConfigData {
  final String version;
  final String versionInfo;
  final String appUpdateShow;
  final String appUpdateUrl;
  final String appUpdateMust;

  CloudAppConfigData({
    required this.version,
    required this.versionInfo,
    required this.appUpdateShow,
    required this.appUpdateUrl,
    required this.appUpdateMust,
  });

  factory CloudAppConfigData.fromJson(Map<String, dynamic> json) {
    return CloudAppConfigData(
      version: json['version'] ?? '',
      versionInfo: json['version_info'] ?? '',
      appUpdateShow: json['app_update_show'] ?? '',
      appUpdateUrl: json['app_update_url'] ?? '',
      appUpdateMust: json['app_update_must'] ?? 'n',
    );
  }

  /// 是否强制更新
  bool get isForceUpdate => appUpdateMust.toLowerCase() == 'y';

  /// 获取格式化的版本信息列表
  List<String> get formattedVersionInfo {
    return versionInfo.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }
}

/// 星河云验证 - 应用公告响应
class CloudNoticeResponse {
  final int code;
  final CloudNoticeData? msg;
  final int time;
  final String check;

  CloudNoticeResponse({
    required this.code,
    this.msg,
    required this.time,
    required this.check,
  });

  factory CloudNoticeResponse.fromJson(Map<String, dynamic> json) {
    return CloudNoticeResponse(
      code: json['code'] ?? 0,
      msg: json['msg'] != null ? CloudNoticeData.fromJson(json['msg']) : null,
      time: json['time'] ?? 0,
      check: json['check'] ?? '',
    );
  }

  bool get isSuccess => code == 200;
}

/// 星河云验证 - 应用公告数据
class CloudNoticeData {
  final String appGg;

  CloudNoticeData({
    required this.appGg,
  });

  factory CloudNoticeData.fromJson(Map<String, dynamic> json) {
    return CloudNoticeData(
      appGg: json['app_gg'] ?? '',
    );
  }

  /// 获取格式化的公告内容列表
  List<String> get formattedNotices {
    return appGg.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }
}


