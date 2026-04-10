import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/language_provider.dart';
import '../widgets/common_widgets.dart';
import 'story_detail_screen.dart';
import 'story_list_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String initialLang;

  const HistoryScreen({super.key, required this.initialLang});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  // 存储键名
  final String _historyKey = 'yumai_history';

  // 多语言文本
  final Map<String, Map<String, String>> _translations = {
    'zh': {
      'back': '返回',
      'title': '历史浏览',
      'statsLabel': '浏览记录',
      'empty': '暂无浏览记录',
      'emptyDesc': '去阅读一些故事吧',
      'browse': '浏览故事',
      'today': '今天',
      'yesterday': '昨天',
      'earlier': '更早',
      'confirmClear': '确定要清空所有历史记录吗？',
      'clearSuccess': '历史记录已清空',
      'justNow': '刚刚',
      'minutes': '{n}分钟前',
      'hours': '{n}小时前',
      'days': '{n}天前',
      'clearAll': '清空历史',
      'remove': '移除',
    },
    'bo': {
      'back': 'ཕྱིར་ལོག',
      'title': 'ལོ་རྒྱུས།',
      'statsLabel': 'ལོ་རྒྱུས།',
      'empty': 'ལོ་རྒྱུས་མེད།',
      'emptyDesc': 'སྒྲུང་ལ་གཟིགས་རོགས།',
      'browse': 'སྒྲུང་ལ་བལྟ།',
      'today': 'དེ་རིང་།',
      'yesterday': 'ཁ་སང་།',
      'earlier': 'སྔ་མོ།',
      'confirmClear': 'ལོ་རྒྱུས་ཡོངས་སེལ་ངེས་ཡིན།',
      'clearSuccess': 'ལོ་རྒྱུས་སེལ་ཟིན།',
      'justNow': 'ད་ལྟ།',
      'minutes': '{n} སྐར་མ་འདས།',
      'hours': '{n} ཆུ་ཚོད་འདས།',
      'days': '{n} ཉིན་འདས།',
      'clearAll': 'ཡོངས་སེལ།',
      'remove': 'སེལ་བ།',
    },
    'ii': {
      'back': 'ꌠꅇꂘ',
      'title': 'ꐘꀨ',
      'statsLabel': 'ꐘꀨ',
      'empty': 'ꐘꀨ ꀋꐥ',
      'emptyDesc': 'ꀉꂿꄯꒉ ꐘꀨ',
      'browse': 'ꀉꂿꄯꒉ ꐘꀨ',
      'today': 'ꉐꆹ',
      'yesterday': 'ꀋꉐ',
      'earlier': 'ꀋꉐꀋꉐ',
      'confirmClear': 'ꐘꀨ ꌠꅇꂘ',
      'clearSuccess': 'ꐘꀨ ꌠꅇꂘꀐ',
      'justNow': 'ꀋꁨ',
      'minutes': '{n} ꑍꇁ',
      'hours': '{n} ꉐꆹ',
      'days': '{n} ꑍ',
      'clearAll': 'ꌠꅇꂘ',
      'remove': 'ꌠꅇꂘ',
    },
  };

  String _t(String key) {
    final lang = context.watch<LanguageProvider>().currentLang;
    return _translations[lang]?[key] ?? _translations['zh']?[key] ?? key;
  }

  String get _currentLang {
    try {
      return context.watch<LanguageProvider>().currentLang;
    } catch (_) {
      return widget.initialLang;
    }
  }

  void _saveLanguage(String lang) {
    context.read<LanguageProvider>().setLanguage(lang);
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_historyKey);
      if (data != null) {
        final List<dynamic> list = json.decode(data);
        _history = list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateGroup(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return _t('earlier');
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
        return _t('today');
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day)
        return _t('yesterday');
      return _t('earlier');
    } catch (_) {
      return _t('earlier');
    }
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return _t('justNow');
      if (diff.inMinutes < 60)
        return _t('minutes').replaceAll('{n}', '${diff.inMinutes}');
      if (diff.inHours < 24)
        return _t('hours').replaceAll('{n}', '${diff.inHours}');
      return _t('days').replaceAll('{n}', '${diff.inDays}');
    } catch (_) {
      return '';
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('confirmClear')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('confirm')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      await _loadHistory();
    }
  }

  Future<void> _removeFromHistory(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_historyKey);
    if (data != null) {
      final List<dynamic> list = json.decode(data);
      final updated = list.where((item) => item['id'] != id).toList();
      await prefs.setString(_historyKey, json.encode(updated));
      await _loadHistory();
    }
  }

  Widget _buildLangOption(String lang, String label) {
    final isActive = _currentLang == lang;
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _saveLanguage(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (isDark ? AppColors.darkText : AppColors.lightText),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final backgroundColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSec
        : AppColors.lightTextSec;
    final danger = AppColors.danger;

    // 按时间倒序排列
    final sortedHistory = List<Map<String, dynamic>>.from(_history)
      ..sort((a, b) {
        final aTime = DateTime.parse(a['viewedAt'] ?? '2000-01-01');
        final bTime = DateTime.parse(b['viewedAt'] ?? '2000-01-01');
        return bTime.compareTo(aTime);
      });

    // 按日期分组
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var record in sortedHistory) {
      final group = _formatDateGroup(record['viewedAt']);
      groups.putIfAbsent(group, () => []).add(record);
    }
    final groupOrder = [_t('today'), _t('yesterday'), _t('earlier')];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _t('back'),
                            style: TextStyle(fontSize: 14, color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _t('title'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  buildLanguageSwitcher(
                    fontSize: 14,
                    iconSize: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                  ),
                ],
              ),
            ),

            // 多语言副标题
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 16,
                children: [
                  Text(
                    'ལོ་རྒྱུས།',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontFamily: 'Noto Serif Tibetan',
                    ),
                  ),
                  Text(
                    '·',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  Text(
                    'ꐘꀨ',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontFamily: 'Noto Sans Yi',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : _history.isEmpty
                  ? _buildEmptyState(primary, textPrimary, textSecondary)
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // 统计卡片
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.history,
                                  size: 24,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t('statsLabel'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _history.length.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_history.isNotEmpty)
                                GestureDetector(
                                  onTap: _clearHistory,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: danger.withAlpha(25),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: danger),
                                    ),
                                    child: Text(
                                      _t('clearAll'),
                                      style: TextStyle(
                                        color: danger,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 分组列表
                        ...groupOrder.map((groupName) {
                          final records = groups[groupName];
                          if (records == null || records.isEmpty)
                            return const SizedBox();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ...records.map(
                                (record) => _buildTimelineItem(
                                  record,
                                  primary,
                                  secondary,
                                  surfaceColor,
                                  borderColor,
                                  textPrimary,
                                  textSecondary,
                                  danger,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    Color primary,
    Color textPrimary,
    Color textSecondary,
  ) {
    return EmptyStateWidget(
      icon: Icons.history,
      title: _t('empty'),
      subtitle: _t('emptyDesc'),
      onAction: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoryListScreen(initialLang: _currentLang),
          ),
        );
      },
      actionText: _t('browse'),
    );
  }

  Widget _buildTimelineItem(
    Map<String, dynamic> record,
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color danger,
  ) {
    final viewedDate = DateTime.parse(record['viewedAt']);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(
              storyId: record['storyId'],
              initialLang: _currentLang,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // 日期显示
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    viewedDate.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  Text(
                    '${viewedDate.month}月',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 故事图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book, size: 22, color: primary),
            ),
            const SizedBox(width: 12),
            // 故事信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['title'] ?? '未知故事',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (record['ethnic'] != null &&
                      record['ethnic'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: secondary.withAlpha(38),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record['ethnic'],
                        style: TextStyle(fontSize: 10, color: secondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRelativeTime(record['viewedAt']),
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _removeFromHistory(record['id']),
                  child: Icon(Icons.close, size: 16, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
