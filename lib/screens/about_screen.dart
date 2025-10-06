import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../utils/snackbar_utils.dart';
import 'feedback_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('关于我们', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 应用信息
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C9678), Color(0xFF46B696)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2C9678).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 背景装饰
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Opacity(
                      opacity: 0.1,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  // 内容
                  Column(
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.note_alt_outlined,
                            size: 40,
                            color: Color(0xFF2C9678),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppConfig.appName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '版本 ${AppConfig.appVersion}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '静待沉淀，蓄势鸣响。\n你的每一次落笔，都是未来生长的根源。',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 应用介绍
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
              children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '关于InkRoot',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'InkRoot-墨鸣笔记是一款基于Memos系统打造的极简跨平台笔记应用，专为追求高效记录与深度积累的用户设计。应用完美对接Memos 0.21.0版本，提供纯净优雅的写作体验，帮助您默默书写、静待沉淀。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                const Text(
                    '基于Flutter 3.32.5打造的跨平台架构，支持Android、iOS、Web三大平台。采用Material Design 3设计语言，提供丰富的Markdown支持、智能标签系统、全文搜索、数据统计热力图等功能，满足从个人记录到知识管理的多样化需求。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF666666),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                    '数据安全是我们的核心承诺。应用支持本地SQLite存储、敏感信息加密、HTTPS安全传输，以及完整的用户权限管理。支持私有化部署，数据完全由您掌控，无论是个人创作还是团队协作，都能获得企业级的安全保障。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
              ),
            ),

            // 核心功能
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                ),
              ],
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                      Icon(
                        Icons.star_outline,
                        color: theme.primaryColor,
                        size: 20,
                    ),
                      const SizedBox(width: 10),
                      Text(
                        '核心功能',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                    ),
                ),
              ],
            ),
                  const SizedBox(height: 16),
                  const Text(
                    'InkRoot-墨鸣笔记基于Flutter 3.32.5和Dart 3.0+构建，采用现代化的架构设计，提供全平台一致的用户体验。集成丰富的功能特性，从基础的笔记记录到高级的知识管理，满足各种使用场景。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildFeatureTag(context, 'Memos 0.21.0专版', Icons.verified_outlined),
                      _buildFeatureTag(context, 'Flutter 3.32.5', Icons.flutter_dash),
                      _buildFeatureTag(context, 'Material Design 3', Icons.design_services),
                      _buildFeatureTag(context, 'Markdown支持', Icons.code),
                      _buildFeatureTag(context, '智能标签系统', Icons.local_offer_outlined),
                      _buildFeatureTag(context, '全文搜索', Icons.search_outlined),
                      _buildFeatureTag(context, '随机回顾', Icons.shuffle_outlined),
                      _buildFeatureTag(context, '数据统计', Icons.analytics_outlined),
                      _buildFeatureTag(context, '实时同步', Icons.sync_outlined),
                      _buildFeatureTag(context, '本地加密', Icons.security_outlined),
                      _buildFeatureTag(context, '多主题切换', Icons.palette_outlined),
                      _buildFeatureTag(context, 'Android/iOS/Web', Icons.devices_outlined),
                      _buildFeatureTag(context, '离线使用', Icons.offline_bolt_outlined),
                      _buildFeatureTag(context, '数据导出', Icons.download_outlined),
                      _buildFeatureTag(context, '图片管理', Icons.image_outlined),
                      _buildFeatureTag(context, '私有化部署', Icons.cloud_outlined),
                    ],
                  ),
                ],
              ),
            ),

            // 联系方式
            Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                        Icons.phone_outlined,
                        color: theme.primaryColor,
                        size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                        '联系我们',
                        style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
                  const Text(
                    '我们非常重视用户的反馈和建议。如果您有任何问题、意见或合作意向，请随时与我们联系。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactItem(
                    context,
                    icon: Icons.feedback_outlined,
                    label: '反馈建议',
                    value: '点击提交反馈建议',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _buildContactItem(
                    context,
                    icon: Icons.email_outlined,
                    label: '电子邮件',
                    value: AppConfig.supportEmail,
                    onTap: () => _launchURL('mailto:${AppConfig.supportEmail}'),
                  ),
                  const Divider(height: 24),
                  _buildContactItem(
                    context,
                    icon: Icons.language_outlined,
                    label: '官方网站',
                    value: AppConfig.officialWebsite,
                    onTap: () => _launchURL(AppConfig.officialWebsite),
                  ),
                  const Divider(height: 24),
                  _buildContactItem(
                    context,
                    icon: Icons.location_on_outlined,
                    label: '交流地址',
                    value: AppConfig.companyAddress,
                    onTap: () {},
                  ),
        ],
              ),
            ),

            // 社交链接
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    context,
                    icon: Icons.access_time,
                    onTap: () => _showPlatformDialog(context, 'QQ'),
                  ),
                  const SizedBox(width: 16),
                  _buildSocialButton(
                    context,
                    icon: Icons.code,
                    onTap: () => _showPlatformDialog(context, 'GitHub'),
                  ),
                  const SizedBox(width: 16),
                  _buildSocialButton(
                    context,
                    icon: Icons.email_outlined,
                    onTap: () => _showPlatformDialog(context, '邮箱'),
                  ),
                  const SizedBox(width: 16),
                  _buildSocialButton(
                    context,
                    icon: Icons.chat_outlined,
                    onTap: () => _showPlatformDialog(context, '微信'),
                  ),
                ],
              ),
            ),

            // 版权信息
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  Text(
                    AppConfig.copyrightText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConfig.companyFullName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                  if (AppConfig.icpLicense.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppConfig.icpLicense,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '版本 ${AppConfig.getFullVersionInfo()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
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

  Widget _buildFeatureTag(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
              color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                  style: TextStyle(
                      fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _showPlatformDialog(BuildContext context, String platform) {
    SnackBarUtils.showInfo(context, '正在打开$platform...');
  }
} 