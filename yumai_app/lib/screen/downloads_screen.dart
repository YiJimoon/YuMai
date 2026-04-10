import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/language_provider.dart';
import '../widgets/common_widgets.dart';
import 'story_detail_screen.dart';
import 'story_list_screen.dart';

class DownloadsScreen extends StatefulWidget {
  final String initialLang;

  const DownloadsScreen({super.key, required this.initialLang});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _offlineStories = [];
  bool _isLoading = true;

  final String _offlineKey = 'yumai_offline_stories';

  final Map<String, Map<String, String>> _translations = {
    'zh': {
      'back': '返回',
      'title': '离线模式',
      'statsLabel': '已下载故事',
      'clearAll': '清空离线',
      'empty': '暂无离线故事',
      'emptyDesc': '去故事列表下载一些故事吧',
      'browse': '浏览故事',
      'offlineBanner': '当前处于离线模式',
      'confirmClear': '确定要清空所有离线故事吗？',
      'clearSuccess': '离线故事已清空',
      'downloaded': '已下载',
      'downloadTime': '下载时间',
      'today': '今天',
      'yesterday': '昨天',
      'daysAgo': '天前',
      'remove': '删除',
    },
    'bo': {
      'back': 'ཕྱིར་ལོག',
      'title': 'ལུང་བ།',
      'statsLabel': 'ཕབ་ལེན་བྱས་པའི་སྒྲུང།',
      'clearAll': 'ཡོངས་སེལ།',
      'empty': 'ལུང་བའི་སྒྲུང་མེད།',
      'emptyDesc': 'སྒྲུང་ཁོངས་ལ་བལྟས་ནས་ཕབ་ལེན་གནང་།',
      'browse': 'སྒྲུང་ལ་བལྟ།',
      'offlineBanner': 'དྲ་རྒྱ་མེད་པའི་རྣམ་པ།',
      'confirmClear': 'ཕབ་ལེན་ཡོངས་སེལ་ངེས་ཡིན།',
      'clearSuccess': 'ཕབ་ལེན་ཡོངས་སེལ་ཟིན།',
      'downloaded': 'ཕབ་ལེན་བྱས།',
      'downloadTime': 'ཕབ་ལེན་དུས།',
      'today': 'དེ་རིང་',
      'yesterday': 'ཁ་སང་',
      'daysAgo': 'ཉིན་འདས།',
      'remove': 'སེལ་བ།',
    },
    'ii': {
      'back': 'ꌠꅇꂘ',
      'title': 'ꌠꅇꂘ',
      'statsLabel': 'ꌠꅇꂘ ꀉꂿꄯꒉ',
      'clearAll': 'ꌠꅇꂘ',
      'empty': 'ꌠꅇꂘ ꀋꐥ',
      'emptyDesc': 'ꀉꂿꄯꒉ ꐘꀨ ꌠꅇꂘ',
      'browse': 'ꀉꂿꄯꒉ ꐘꀨ',
      'offlineBanner': 'ꃅꇢꇬꄉ ꌠꅇꂘ',
      'confirmClear': 'ꌠꅇꂘ ꌠꅇꂘ',
      'clearSuccess': 'ꌠꅇꂘ ꀐ',
      'downloaded': 'ꌠꅇꂘꀐ',
      'downloadTime': 'ꌠꅇꂘ ꄮ',
      'today': 'ꄚꐊ',
      'yesterday': 'ꁧꇁ',
      'daysAgo': 'ꉆꇁ',
      'remove': 'ꌠꅇꂘ',
    },
  };

  String _t(String key) {
    final lang = context.watch<LanguageProvider>().currentLang;
    final safeLang = ['zh', 'bo', 'ii'].contains(lang) ? lang : 'zh';
    return _translations[safeLang]?[key] ?? _translations['zh']?[key] ?? key;
  }

  String get _currentLang {
    try {
      return context.watch<LanguageProvider>().currentLang;
    } catch (_) {
      return widget.initialLang;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOfflineStories();
  }

  Future<void> _loadOfflineStories() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_offlineKey);
      if (data != null) {
        final Map<String, dynamic> offlineMap = json.decode(data);
        _offlineStories = offlineMap.values
            .cast<Map<String, dynamic>>()
            .toList();
      }
    } catch (e) {
      debugPrint('加载离线故事失败: $e');
      _offlineStories = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDisplayTitle(Map<String, dynamic> story) {
    final lang = _currentLang;
    if (lang == 'bo' && story['title_bo'] != null) return story['title_bo'];
    if (lang == 'ii' && story['title_ii'] != null) return story['title_ii'];
    return story['title'] ?? '';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _removeOfflineStory(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineKey);
    if (data != null) {
      final Map<String, dynamic> offlineMap = json.decode(data);
      offlineMap.remove(storyId);
      await prefs.setString(_offlineKey, json.encode(offlineMap));
      await _loadOfflineStories();
    }
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
    final success = AppColors.success;

    final storyList = _offlineStories.toList()
      ..sort((a, b) {
        final aTime = DateTime.parse(a['downloadedAt'] ?? '2000-01-01');
        final bTime = DateTime.parse(b['downloadedAt'] ?? '2000-01-01');
        return bTime.compareTo(aTime);
      });

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
                    'ལུང་བ།',
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
                    'ꌠꅇꂘ',
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
                  : storyList.isEmpty
                  ? _buildEmptyState(primary, textPrimary, textSecondary)
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: storyList.length,
                      itemBuilder: (context, index) => _buildStoryCard(
                        storyList[index],
                        primary,
                        secondary,
                        surfaceColor,
                        borderColor,
                        textPrimary,
                        textSecondary,
                        success,
                        danger,
                      ),
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
      icon: Icons.download_outlined,
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

  Widget _buildStoryCard(
    Map<String, dynamic> story,
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color success,
    Color danger,
  ) {
    final displayTitle = _getDisplayTitle(story);
    final downloadTime = _formatDate(story['downloadedAt'] ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(
              storyId: story['id'],
              initialLang: _currentLang,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: primary.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 民族标签
            if (story['ethnic'] != null && story['ethnic'].isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: secondary.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  story['ethnic'],
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 标题
            Text(
              displayTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 底部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 离线标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_done, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _t('downloaded'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  downloadTime,
                  style: TextStyle(fontSize: 10, color: textSecondary),
                ),
                GestureDetector(
                  onTap: () => _removeOfflineStory(story['id'].toString()),
                  child: Icon(Icons.close, size: 16, color: danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
