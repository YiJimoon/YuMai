import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/language_provider.dart';
import '../widgets/common_widgets.dart';
import 'story_detail_screen.dart';
import 'story_list_screen.dart';

class BookshelfScreen extends StatefulWidget {
  final String initialLang;

  const BookshelfScreen({super.key, required this.initialLang});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  List<Map<String, dynamic>> _bookshelf = [];
  bool _isLoading = true;

  final String _bookshelfKey = 'yumai_bookshelf';

  final Map<String, Map<String, String>> _translations = {
    'zh': {
      'back': '返回',
      'title': '书架',
      'statsLabel': '已收藏故事',
      'empty': '书架空空如也',
      'emptyDesc': '去故事列表添加一些故事吧',
      'browse': '浏览故事',
      'confirmClear': '确定要清空书架吗？',
      'clearSuccess': '书架已清空',
      'added': '已添加',
      'remove': '移除',
      'clearAll': '清空书架',
      'recent': '近期添加',
    },
    'bo': {
      'back': 'ཕྱིར་ལོག',
      'title': 'ཕབ་ལེན།',
      'statsLabel': 'ཕབ་ལེན་བྱས་པའི་སྒྲུང།',
      'empty': 'ཕབ་ལེན་མེད།',
      'emptyDesc': 'སྒྲུང་ཁོངས་ལ་བལྟས་ནས་ཕབ་ལེན་གནང་།',
      'browse': 'སྒྲུང་ལ་བལྟ།',
      'confirmClear': 'ཕབ་ལེན་ཡོངས་སེལ་ངེས་ཡིན།',
      'clearSuccess': 'ཕབ་ལེན་ཡོངས་སེལ་ཟིན།',
      'added': 'ཕབ་ལེན་བྱས།',
      'remove': 'སེལ་བ།',
      'clearAll': 'ཡོངས་སེལ།',
      'recent': 'ཉེ་ཆར་ཕབ་ལེན།',
    },
    'ii': {
      'back': 'ꌠꅇꂘ',
      'title': 'ꌠꅇꂘ',
      'statsLabel': 'ꌠꅇꂘ ꀉꂿꄯꒉ',
      'empty': 'ꌠꅇꂘ ꀋꐥ',
      'emptyDesc': 'ꀉꂿꄯꒉ ꐘꀨ ꌠꅇꂘ',
      'browse': 'ꀉꂿꄯꒉ ꐘꀨ',
      'confirmClear': 'ꌠꅇꂘ ꌠꅇꂘ',
      'clearSuccess': 'ꌠꅇꂘ ꀐ',
      'added': 'ꌠꅇꂘꀐ',
      'remove': 'ꌠꅇꂘ',
      'clearAll': 'ꌠꅇꂘ',
      'recent': 'ꌠꅇꂘꀐ',
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

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  Future<void> _loadBookshelf() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_bookshelfKey);
      if (data != null) {
        final List<dynamic> list = json.decode(data);
        _bookshelf = list
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      // ignore
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

  Future<void> _removeFromBookshelf(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookshelfKey);
    if (data != null) {
      final List<dynamic> list = json.decode(data);
      final updated = list
          .where((item) => item['id'].toString() != storyId)
          .toList();
      await prefs.setString(_bookshelfKey, json.encode(updated));
      await _loadBookshelf();
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
                    'ཕབ་ལེན།',
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
                  : _bookshelf.isEmpty
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
                      itemCount: _bookshelf.length,
                      itemBuilder: (context, index) => _buildStoryCard(
                        _bookshelf[index],
                        primary,
                        secondary,
                        surfaceColor,
                        borderColor,
                        textPrimary,
                        textSecondary,
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
      icon: Icons.bookmark_border,
      title: _t('empty'),
      subtitle: _t('emptyDesc'),
      onAction: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryListScreen(initialLang: _currentLang),
          ),
        );
        if (result == true) _loadBookshelf();
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
    Color danger,
  ) {
    final displayTitle = _getDisplayTitle(story);
    final addedDate = _formatDate(story['addedAt']);

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailScreen(
              storyId: story['id'],
              initialLang: _currentLang,
            ),
          ),
        );
        if (changed == true) await _loadBookshelf();
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
                Row(
                  children: [
                    Icon(Icons.star_border, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      addedDate,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _removeFromBookshelf(story['id'].toString()),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
