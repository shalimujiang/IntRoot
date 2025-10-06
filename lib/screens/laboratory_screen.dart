import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/app_theme.dart';
import '../utils/snackbar_utils.dart';

class LaboratoryScreen extends StatefulWidget {
  const LaboratoryScreen({super.key});

  @override
  State<LaboratoryScreen> createState() => _LaboratoryScreenState();
}

class _LaboratoryScreenState extends State<LaboratoryScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : null),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '实验室', 
          style: TextStyle(
            fontSize: 17, 
            fontWeight: FontWeight.w600,
            color: textColor,
          )
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部介绍卡片
            _buildHeaderCard(isDarkMode, textColor, secondaryTextColor),
            
            const SizedBox(height: 24),

            // 已发布功能
            _buildSectionHeader('已发布功能', Icons.check_circle, Colors.green, textColor),
            const SizedBox(height: 12),
            _buildReleasedFeatures(isDarkMode, textColor, secondaryTextColor),

            const SizedBox(height: 32),

            // 开发中功能
            _buildSectionHeader('开发中功能', Icons.build, Colors.orange, textColor),
            const SizedBox(height: 12),
            _buildDevelopingFeatures(isDarkMode, textColor, secondaryTextColor),

            const SizedBox(height: 32),

            // 底部提示
            _buildFooterTip(isDarkMode, secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDarkMode, Color textColor, Color? secondaryTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [Colors.indigo[800]!.withOpacity(0.4), Colors.purple[800]!.withOpacity(0.4)]
            : [Colors.indigo[50]!, Colors.purple[50]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.indigo[700]!.withOpacity(0.3) : Colors.indigo[100]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.indigo[700]!.withOpacity(0.5) : Colors.indigo[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.science_outlined,
              color: isDarkMode ? Colors.indigo[200] : Colors.indigo[700],
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '实验室',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '探索前沿功能，体验创新特性\n这里是我们测试和孵化新想法的地方',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildReleasedFeatures(bool isDarkMode, Color textColor, Color? secondaryTextColor) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.grey[50]!;
    
    return Column(
      children: [
        // Telegram 助手
        _buildModernFeatureCard(
          context: context,
          icon: Icons.telegram,
          iconColor: Colors.blue,
          title: 'Telegram 助手',
          subtitle: '连接 InkRoot_Bot，实现跨平台笔记同步',
          status: '稳定运行',
          statusColor: Colors.green,
          cardColor: cardColor,
          onTap: () => _showTelegramBotDialog(context),
          isDarkMode: isDarkMode,
          isNew: false,
        ),

        const SizedBox(height: 12),

        // 语音转文字
        _buildModernFeatureCard(
          context: context,
          icon: Icons.mic_outlined,
          iconColor: Colors.purple,
          title: '语音转文字',
          subtitle: '语音录制自动转换为文字笔记',
          status: '稳定运行',
          statusColor: Colors.green,
          cardColor: cardColor,
          onTap: () => _showSpeechToTextTutorial(context),
          isDarkMode: isDarkMode,
          isNew: true,
        ),
      ],
    );
  }

  Widget _buildDevelopingFeatures(bool isDarkMode, Color textColor, Color? secondaryTextColor) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.grey[50]!;
    
    return Column(
      children: [
        // AI 笔记助手
        _buildModernFeatureCard(
          context: context,
          icon: Icons.auto_awesome,
          iconColor: Colors.orange,
          title: 'AI 笔记助手',
          subtitle: '智能分析和优化您的笔记内容',
          status: '开发中',
          statusColor: Colors.orange,
          cardColor: cardColor,
          onTap: () => _showComingSoonDialog(context, 'AI 笔记助手'),
          isDarkMode: isDarkMode,
          isNew: false,
          isDeveloping: true,
        ),
      ],
    );
  }

  Widget _buildModernFeatureCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color cardColor,
    required VoidCallback onTap,
    required bool isDarkMode,
    bool isNew = false,
    bool isDeveloping = false,
  }) {
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 图标容器
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 内容区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                          // 状态标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          // 新功能标签
                          if (isNew) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[400]!, Colors.pink[400]!],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          height: 1.3,
                        ),
                      ),
                      // 开发进度指示器
                      if (isDeveloping) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '预计下个版本发布',
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 箭头
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: secondaryTextColor?.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterTip(bool isDarkMode, Color? secondaryTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.amber[900]?.withOpacity(0.2) : Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.amber[800]!.withOpacity(0.3) : Colors.amber[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '实验室说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '实验室功能可能不稳定，使用前请备份重要数据。我们会根据用户反馈不断改进这些功能。',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTelegramBotDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.telegram,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram 助手',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '连接 InkRoot_Bot',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 机器人信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blue[800]?.withOpacity(0.1) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.smart_toy,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '机器人名称：InkRoot_Bot',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '使用说明：',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'telegram 搜索 @InkRoot_Bot 开始使用',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(context, '@InkRoot_Bot'),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制用户名'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTelegram(context),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('打开 Telegram'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 详细说明
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800]?.withOpacity(0.3) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '功能特性：',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• 发送消息自动创建笔记\n'
                        '• 支持 Markdown 格式\n'
                        '• 实时同步到 InkRoot 应用\n'
                        '• 在 Telegram 中搜索 @InkRoot_Bot',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '即将推出',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '$featureName 功能正在开发中，敬请期待！',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarUtils.showSuccess(context, '已复制到剪贴板');
  }

  Future<void> _openTelegram(BuildContext context) async {
    const telegramUrl = 'https://t.me/InkRoot_Bot';
    try {
      final uri = Uri.parse(telegramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          SnackBarUtils.showWarning(context, '无法打开 Telegram，请手动搜索 @InkRoot_Bot');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '打开失败，请手动搜索 @InkRoot_Bot');
      }
    }
  }

  // 显示语音转文字教程
  void _showSpeechToTextTutorial(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode ? AppTheme.darkTextSecondaryColor : Colors.grey[600];
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
            return Dialog(
          backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                    padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // 标题
                    Row(
                      children: [
                        Container(
                        padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.mic_outlined,
                          color: Colors.purple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                              '语音转文字使用教程',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            const SizedBox(height: 4),
                              Text(
                              '离线语音识别功能',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                  // 功能介绍
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                      color: isDarkMode ? Colors.purple[800]?.withOpacity(0.2) : Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.purple,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '功能特性',
                                style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• 离线语音识别，无需联网即可使用\n'
                          '• 支持中文普通话识别\n'
                          '• 实时显示识别结果\n'
                          '• 连续识别模式，自动断句\n'
                          '• 可随时暂停和继续',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            height: 1.5,
                          ),
                                  ),
                                ],
                              ),
                  ),

                  const SizedBox(height: 20),

                  // 使用步骤
                                  Text(
                    '使用步骤',
                                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                                        color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTutorialStep(
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor!,
                    stepNumber: '1',
                    stepColor: Colors.blue,
                    title: '打开笔记编辑器',
                    description: '在首页点击右下角的"+"按钮，或打开已有笔记进行编辑',
                  ),

                  const SizedBox(height: 12),

                  _buildTutorialStep(
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    stepNumber: '2',
                    stepColor: Colors.green,
                    title: '点击语音按钮',
                    description: '在编辑器右上角找到麦克风图标按钮，点击开始语音识别',
                  ),

                  const SizedBox(height: 12),

                  _buildTutorialStep(
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    stepNumber: '3',
                    stepColor: Colors.orange,
                    title: '授权麦克风权限',
                    description: '首次使用时需要授予麦克风权限，请在弹出的对话框中允许访问',
                  ),

                  const SizedBox(height: 12),

                  _buildTutorialStep(
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    stepNumber: '4',
                    stepColor: Colors.purple,
                    title: '开始说话',
                    description: '看到麦克风按钮变为紫色动画时，表示正在监听，可以开始说话了',
                  ),

                  const SizedBox(height: 12),

                  _buildTutorialStep(
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    stepNumber: '5',
                    stepColor: Colors.red,
                    title: '停止识别',
                    description: '说完后再次点击麦克风按钮停止识别，文字将自动插入到编辑器中',
                  ),

                  const SizedBox(height: 24),

                  // 注意事项
                            Container(
                    padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                      color: isDarkMode ? Colors.amber[900]?.withOpacity(0.2) : Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode ? Colors.amber[800]!.withOpacity(0.3) : Colors.amber[200]!,
                        width: 1,
                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber[700],
                              size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                              '注意事项',
                                        style: TextStyle(
                                fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                color: Colors.amber[700],
                                        ),
                                      ),
                                    ],
                                  ),
                        const SizedBox(height: 12),
                                  Text(
                          '• 请在安静的环境中使用，以获得更好的识别效果\n'
                          '• 说话时保持正常语速，吐字清晰\n'
                          '• 如果识别不准确，可以手动修改文字\n'
                          '• Android 设备需要安装语音引擎才能使用\n'
                          '• 部分旧设备可能不支持离线语音识别',
                                    style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                  // 关闭按钮
                      SizedBox(
                        width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                      child: const Text(
                        '知道了',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建教程步骤
  Widget _buildTutorialStep({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
    required String stepNumber,
    required Color stepColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800]?.withOpacity(0.3) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤编号
                      Container(
            width: 32,
            height: 32,
                        decoration: BoxDecoration(
              color: stepColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 步骤内容
          Expanded(
                        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                  title,
                              style: TextStyle(
                    fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                const SizedBox(height: 4),
                            Text(
                  description,
                              style: TextStyle(
                    fontSize: 13,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
        ],
      ),
    );
  }
} 