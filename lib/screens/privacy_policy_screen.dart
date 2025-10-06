import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../themes/app_theme.dart';
import '../config/app_config.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : Colors.grey.shade50;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final accentColor = isDarkMode ? AppTheme.primaryLightColor : Colors.teal;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('隐私政策', style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Center(
                child: Text(
                  '${AppConfig.appName} 隐私政策',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '最后更新日期：${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 重要声明
              _buildSection(
                '重要声明',
                '${AppConfig.appName} 不收集、存储或处理任何个人数据。所有您的笔记和个人信息都直接存储在您自己的Memos服务器上，我们无法访问这些数据。本应用遵循数据最小化原则，仅在必要时处理用户数据。',
                textColor,
                accentColor,
                isHighlight: true,
              ),

              // 信息收集
              _buildSection(
                '信息收集与处理',
                '我们不收集以下信息：\n'
                '• 个人身份信息（姓名、邮箱、电话号码等）\n'
                '• 设备唯一标识符（IMEI、MAC地址等）\n'
                '• 位置信息和地理数据\n'
                '• 使用统计和行为分析数据\n'
                '• 崩溃报告和错误日志\n'
                '• 广告标识符\n'
                '• 生物识别信息\n\n'
                '本地存储的信息：\n'
                '• 服务器连接配置（服务器地址、访问令牌）\n'
                '• 应用设置和用户偏好\n'
                '• 笔记的本地缓存（SQLite数据库，用于离线访问）\n'
                '• 图片文件的临时缓存\n'
                '• 应用版本和配置信息\n\n'
                '技术实现：\n'
                '• 使用 SharedPreferences 存储应用配置\n'
                '• 使用 Flutter Secure Storage 保护敏感数据\n'
                '• 使用 SQLite 数据库存储笔记缓存\n'
                '• 所有本地数据受系统级加密保护\n\n'
                '这些信息仅存储在您的设备上，不会传输给我们或任何第三方。',
                textColor,
                accentColor,
              ),

              // 数据传输
              _buildSection(
                '数据传输与安全',
                '${AppConfig.appName} 仅与以下服务进行有限的数据通信：\n\n'
                '主要数据流向：\n'
                '• 您的设备 ↔ 您指定的Memos服务器（笔记数据同步）\n'
                '• 您的设备 ↔ ${AppConfig.apiBaseUrl}（版本检查和公告获取）\n'
                '• 您的设备 ↔ Telegram（可选，用户主动使用Bot功能时）\n\n'
                '数据安全保障：\n'
                '• 强制使用HTTPS/TLS加密传输\n'
                '• 本地敏感数据使用系统级Keychain/Keystore保护\n'
                '• 访问令牌使用Flutter Secure Storage加密存储\n'
                '• 图片上传直接到您的服务器，不经过我们的服务器\n'
                '• 应用内网络请求使用安全的HTTP客户端\n'
                '• 不进行中间人攻击防护\n\n'
                '第三方服务：\n'
                '• 官方API服务：仅用于应用更新检查和系统公告\n'
                '• Telegram Bot：仅在用户主动选择时连接\n'
                '• 图片CDN：不使用第三方图片托管服务',
                textColor,
                accentColor,
              ),

              // 权限使用
              _buildSection(
                '系统权限说明',
                '本应用请求以下系统权限，均有明确用途：\n\n'
                '📱 相册/照片权限：\n'
                '• 用途：选择图片添加到笔记中\n'
                '• 处理方式：选择的图片直接上传到您的Memos服务器\n'
                '• 数据去向：仅存储在您的设备和指定服务器\n'
                '• 隐私保护：我们无法访问您的相册内容\n\n'
                '💾 存储权限：\n'
                '• 用途：导入导出笔记文件，保存分享图片\n'
                '• 处理方式：仅访问用户主动选择的文件\n'
                '• 数据去向：保存到设备本地存储\n'
                '• 隐私保护：不扫描或访问其他文件\n\n'
                '🌐 网络权限：\n'
                '• 用途：与Memos服务器同步，检查应用更新\n'
                '• 处理方式：仅连接用户指定的服务器\n'
                '• 数据传输：全程HTTPS加密\n'
                '• 隐私保护：不收集网络使用统计\n\n'
                '🔔 通知权限（可选）：\n'
                '• 用途：显示同步状态和重要提醒\n'
                '• 处理方式：本地生成，不涉及远程推送\n'
                '• 隐私保护：可随时在系统设置中关闭',
                textColor,
                accentColor,
              ),

              // 数据控制
              _buildSection(
                '您的权利',
                '数据控制：\n'
                '• 您完全控制自己的所有数据\n'
                '• 您可以随时删除、修改或导出您的笔记\n'
                '• 您可以随时更改服务器配置或停止使用服务\n\n'
                '应用权限：\n'
                '• 您可以在iOS设置中随时撤销应用权限\n'
                '• 撤销权限可能会影响相关功能的使用',
                textColor,
                accentColor,
              ),

              // 添加新的章节
              _buildSection(
                '未成年人隐私保护',
                '我们特别重视未成年人的隐私保护：\n\n'
                '• 本应用不主动收集13岁以下儿童的任何个人信息\n'
                '• 如发现误收集了儿童信息，我们将立即删除\n'
                '• 建议未成年人在家长监护下使用本应用\n'
                '• 家长可以联系我们了解子女的数据使用情况\n'
                '• 支持家长请求删除未成年人相关数据',
                textColor,
                accentColor,
              ),

              // 数据保留和删除
              _buildSection(
                '数据保留与删除',
                '数据保留政策：\n'
                '• 本地缓存数据：随应用卸载自动清除\n'
                '• 服务器配置：可通过应用设置手动清除\n'
                '• 临时文件：定期自动清理\n'
                '• 应用日志：仅保留在本地，不上传\n\n'
                '用户删除权利：\n'
                '• 随时在应用内清除所有本地数据\n'
                '• 通过"数据清理"功能重置应用\n'
                '• 卸载应用即可完全删除所有本地数据\n'
                '• 服务器数据需在Memos服务器端管理',
                textColor,
                accentColor,
              ),

              // 联系我们
              _buildSection(
                '联系我们',
                '如果您对本隐私政策有任何疑问或建议，请通过以下方式联系我们：\n\n'
                                          '反馈建议：设置 → 反馈建议（推荐）\n'
                '邮箱：${AppConfig.supportEmail}\n'
                '应用内反馈：设置 → 意见反馈',
                textColor,
                accentColor,
              ),

              // 总结
              _buildSection(
                '隐私保护原则',
                '1. 🔒 零数据收集：我们不收集您的任何个人数据\n'
                '2. 💻 本地优先：数据主要存储在您的设备和服务器上\n'
                '3. 👁️ 透明公开：开源项目，代码完全透明可审计\n'
                '4. 🎯 用户控制：您完全控制自己的数据\n'
                '5. 🛡️ 安全第一：采用业界标准的安全技术\n'
                '6. ⚖️ 合规经营：遵守相关法律法规要求\n\n'
                '我们承诺持续保护您的隐私，让您安心使用${AppConfig.appName}进行笔记记录。',
                textColor,
                accentColor,
                isHighlight: true,
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  '本隐私政策的英文版本仅供参考，如有冲突，以中文版本为准。',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color textColor, Color accentColor, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: isHighlight ? const EdgeInsets.all(12) : EdgeInsets.zero,
          decoration: isHighlight ? BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ) : null,
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
