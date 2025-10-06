import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// iOS风格的日期时间选择器
/// 符合中国人使用习惯
class IOSDateTimePicker {
  
  /// 显示iOS风格的日期时间选择器
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDateTime,
    DateTime? minimumDateTime,
    DateTime? maximumDateTime,
  }) async {
    final initialDate = initialDateTime ?? DateTime.now().add(const Duration(hours: 1));
    DateTime selectedDateTime = initialDate;
    
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final secondaryColor = isDarkMode ? Colors.white70 : Colors.black54;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头部标题栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity( 0.1) 
                              : Colors.black.withOpacity( 0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          Text(
                            '设置提醒时间',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(selectedDateTime),
                            child: const Text(
                              '确定',
                              style: TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 快捷选项
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '快捷选择',
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _buildQuickOptions(context, (DateTime newTime) {
                              setState(() {
                                selectedDateTime = newTime;
                              });
                            }, isDarkMode),
                          ),
                        ],
                      ),
                    ),
                    
                    // 当前选择的时间显示
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 20,
                            color: secondaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(selectedDateTime),
                            style: const TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 1),
                    
                    // iOS风格的滚轮选择器（中文）
                    SizedBox(
                      height: 216,
                      child: Localizations.override(
                        context: context,
                        locale: const Locale('zh', 'CN'),
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: isDarkMode ? Brightness.dark : Brightness.light,
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                color: textColor,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.dateAndTime,
                            use24hFormat: true,
                            minimumDate: minimumDateTime ?? DateTime.now(),
                            maximumDate: maximumDateTime ?? DateTime.now().add(const Duration(days: 365)),
                            initialDateTime: selectedDateTime,
                            onDateTimeChanged: (DateTime newDateTime) {
                              setState(() {
                                selectedDateTime = newDateTime;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  /// 构建快捷选项按钮
  static List<Widget> _buildQuickOptions(
    BuildContext context,
    Function(DateTime) onSelect,
    bool isDarkMode,
  ) {
    final now = DateTime.now();
    final options = [
      {
        'label': '1小时后',
        'time': now.add(const Duration(hours: 1)),
        'icon': CupertinoIcons.time,
      },
      {
        'label': '今晚8点',
        'time': DateTime(now.year, now.month, now.day, 20, 0),
        'icon': CupertinoIcons.moon_stars,
      },
      {
        'label': '明早9点',
        'time': DateTime(now.year, now.month, now.day + 1, 9, 0),
        'icon': CupertinoIcons.sunrise,
      },
      {
        'label': '明晚8点',
        'time': DateTime(now.year, now.month, now.day + 1, 20, 0),
        'icon': CupertinoIcons.moon,
      },
      {
        'label': '下周一9点',
        'time': _getNextWeekday(now, DateTime.monday, 9),
        'icon': CupertinoIcons.calendar,
      },
    ];
    
    return options.where((option) {
      // 过滤掉已经过去的时间
      return (option['time'] as DateTime).isAfter(now);
    }).map((option) {
      return _QuickOptionChip(
        label: option['label'] as String,
        icon: option['icon'] as IconData,
        onTap: () => onSelect(option['time'] as DateTime),
        isDarkMode: isDarkMode,
      );
    }).toList();
  }
  
  /// 获取下周的某一天
  static DateTime _getNextWeekday(DateTime from, int weekday, int hour) {
    final daysUntilWeekday = (weekday - from.weekday + 7) % 7;
    final nextWeekday = from.add(Duration(days: daysUntilWeekday == 0 ? 7 : daysUntilWeekday));
    return DateTime(nextWeekday.year, nextWeekday.month, nextWeekday.day, hour, 0);
  }
  
  /// 格式化日期时间（中文显示）
  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (dateToCheck == today) {
      dateStr = '今天';
    } else if (dateToCheck == tomorrow) {
      dateStr = '明天';
    } else {
      // 使用中文星期
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final weekday = weekdays[dateTime.weekday - 1];
      dateStr = '${DateFormat('MM月dd日', 'zh_CN').format(dateTime)} $weekday';
    }
    
    final timeStr = DateFormat('HH:mm').format(dateTime);
    return '$dateStr $timeStr';
  }
}

/// 快捷选项芯片组件
class _QuickOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;
  
  const _QuickOptionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode 
              ? const Color(0xFF2C2C2E) 
              : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode 
                ? Colors.white.withOpacity( 0.1) 
                : Colors.black.withOpacity( 0.05),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF007AFF),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

