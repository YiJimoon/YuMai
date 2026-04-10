import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_services.dart';
import '../services/language_provider.dart';
import '../services/translations.dart';
import '../models/story.dart';
import 'story_detail_screen.dart';
import '../widgets/common_widgets.dart';

class StoryListScreen extends StatefulWidget {
  final String initialLang;

  const StoryListScreen({super.key, required this.initialLang});

  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  List<Story> _stories = [];
  List<Story> _displayedStories = [];
  List<Story> _searchResults = [];
  String _currentFilter = 'all'; // 'all' or 'recommended'
  bool _isLoading = true;
  bool _isSearching = false;
  String _errorMessage = '';

  // Search related
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // 多语言翻译 - 直接初始化，确保 build() 前就已准备好
  final Map<String, Map<String, String>> _translations = AppTranslations.storyList;

  // 记录上一次的语言，用于避免重复加载
  String? _previousLang;

  String get _currentLang {
    try {
      return context.watch<LanguageProvider>().currentLang;
    } catch (_) {
      return widget.initialLang;
    }
  }

  String _t(String key) {
    // 直接从 LanguageProvider 获取当前语言，确保语言切换后能拿到最新值
    final lang = context.watch<LanguageProvider>().currentLang;
    final safeLang = ['zh', 'bo', 'ii'].contains(lang) ? lang : 'zh';
    return _translations[safeLang]?[key] ?? _translations['zh']?[key] ?? key;
  }

  /// Convert backend `cover_image` (relative path or absolute URL) to requestable address
  String _absoluteCoverImageUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    var base = ApiService.baseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
  }

  // Recommendation logic (based purely on backend data)
  bool _isRecommended(Story story) {
    // 1. Title contains keywords
    if (story.title.contains('格萨尔') ||
        story.title.contains('史诗') ||
        story.title.contains('英雄')) {
      return true;
    }
    // 2. Intro contains keywords
    if (story.intro.contains('史诗') ||
        story.intro.contains('英雄') ||
        story.intro.contains('传奇')) {
      return true;
    }
    // 3. Ethnic is Tibetan and title contains Gesar (Gesar King is Tibetan epic)
    if (story.ethnic == '藏族' && story.title.contains('格萨尔')) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLang = _currentLang;
    if (_previousLang != currentLang) {
      _previousLang = currentLang;
      _loadStories();
    }
  }

  // Get story list (completely from backend)
  Future<void> _loadStories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 关键修改：传入当前语言
      final stories = await ApiService.getStories(lang: _currentLang);
      setState(() {
        _stories = stories;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (mounted) {
        showErrorDialog(context, 'Failed to load stories: $e');
      }
    }
  }

  // Apply filter and search
  void _applyFilter() {
    final baseList = _searchQuery.isNotEmpty ? _searchResults : _stories;
    var filtered = List<Story>.from(baseList);

    // Filter by recommendation
    if (_currentFilter == 'recommended') {
      filtered = filtered.where((story) => _isRecommended(story)).toList();
    }

    setState(() => _displayedStories = filtered);
  }

  // Switch filter
  void _switchFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _applyFilter();
    });
  }

  // Search
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      if (trimmed.isEmpty) {
        setState(() {
          _searchQuery = '';
          _searchResults = [];
          _isSearching = false;
          _applyFilter();
        });
        return;
      }

      setState(() {
        _searchQuery = trimmed;
        _isSearching = true;
      });

      // 关键修改：传入当前语言
      final results = await ApiService.searchStories(trimmed, lang: _currentLang);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _applyFilter();
      });
    });
  }

  // Clear search
  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
      _applyFilter();
    });
  }

  // Get page title
  String _getPageTitle() => _t('pageTitle');

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? AppColors.darkBg
        : AppColors.lightBg;
    final surfaceColor = brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final textPrimary = brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.lightText;
    final textSecondary = brightness == Brightness.dark
        ? AppColors.darkTextSec
        : AppColors.lightTextSec;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, textPrimary, textSecondary, primary, borderColor, surfaceColor),
            Expanded(
              child: LoadingOverlay(
                isLoading: _isLoading || _isSearching,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildFilterAndSearch(
                        context,
                        surfaceColor,
                        borderColor,
                        primary,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 24),
                      _buildStoryGrid(
                        context,
                        primary,
                        secondary,
                        surfaceColor,
                        borderColor,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(textSecondary, borderColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color primary,
    Color borderColor,
    Color surfaceColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Page title with back button
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary),
                onPressed: () => Navigator.pop(context),
                tooltip: _t('back'),
              ),
              Expanded(
                child: Text(
                  _getPageTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 48), // balance the back button
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _t('pageTitleSubBo'),
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontFamily: 'Noto Serif Tibetan',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '·',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(width: 12),
              Text(
                _t('pageTitleSubIi'),
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontFamily: 'Noto Sans Yi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Language indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 14, color: textSecondary),
                const SizedBox(width: 6),
                Text(
                  _currentLang == 'zh'
                      ? '汉语'
                      : _currentLang == 'bo'
                      ? '藏语'
                      : '彝语',
                  style: TextStyle(fontSize: 13, color: textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Filter and search bar
  Widget _buildFilterAndSearch(
    BuildContext context,
    Color surfaceColor,
    Color borderColor,
    Color primary,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      children: [
        // Filter chips
        Row(
          children: [
            _buildFilterChip(
              context,
              _t('all'),
              'all',
              Icons.menu_book,
              surfaceColor,
              borderColor,
              primary,
              textPrimary,
              textSecondary,
            ),
            const SizedBox(width: 12),
            _buildFilterChip(
              context,
              _t('recommended'),
              'recommended',
              Icons.star,
              surfaceColor,
              borderColor,
              primary,
              textPrimary,
              textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search bar - 填满右侧无空白
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: textSecondary, size: 20),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: _t('searchHint'),
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: textSecondary, size: 18),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Filter chip
  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color surfaceColor,
    Color borderColor,
    Color primary,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isActive = _currentFilter == value;
    return GestureDetector(
      onTap: () => _switchFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primary : surfaceColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isActive ? primary : borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textPrimary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Story grid
  Widget _buildStoryGrid(
    BuildContext context,
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_isLoading || _isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(color: primary),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Text(
                '${_t('loadFailed')}: $_errorMessage',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStories,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_t('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_displayedStories.isEmpty) {
      // No search results
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _t('noResults').replaceAll('#{query}', _searchQuery),
                  style: TextStyle(
                    fontSize: 18,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _clearSearch,
                  child: Text(
                    _t('clearSearch'),
                    style: TextStyle(color: primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Recommended list empty
      if (_currentFilter == 'recommended') {
        return EmptyStateWidget(
          icon: Icons.star,
          title: _t('noRecommend'),
          subtitle: _t('browseMore'),
          onAction: () {
            setState(() {
              _currentFilter = 'all';
              _applyFilter();
            });
          },
          actionText: _t('viewAll'),
        );
      }

      // General empty state
      return EmptyStateWidget(
        icon: Icons.menu_book,
        title: _t('noStoryData'),
        subtitle: _t('networkError'),
        onAction: _loadStories,
        actionText: _t('reload'),
      );
    }

    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: _displayedStories.length,
      itemBuilder: (context, index) {
        final story = _displayedStories[index];
        final cardHeight = _calculateCardHeight(story, index);
        return _buildStoryCard(
          context,
          story,
          primary,
          secondary,
          surfaceColor,
          borderColor,
          cardHeight,
        );
      },
    );
  }

  // 根据故事内容计算卡片高度（瀑布流效果）
  double _calculateCardHeight(Story story, int index) {
    // 基础高度
    double height = 180.0;

    // 推荐的故事更高一些
    if (_isRecommended(story)) {
      height += 30;
    }

    // 根据 intro 长度调整高度（intro 来自 summary，越长卡片越高）
    final introLen = story.intro.length;
    if (introLen > 200) {
      height += 50;
    } else if (introLen > 100) {
      height += 25;
    }

    // 加入一点错位的随机感（偶数索引稍高）
    if (index % 2 == 0) {
      height += 15;
    }

    // 限制最大最小高度
    return height.clamp(160.0, 300.0);
  }

  // Story card - with cover image support
  Widget _buildStoryCard(
    BuildContext context,
    Story story,
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    double cardHeight,
  ) {
    final bool hasCover =
        story.coverImage != null && story.coverImage!.isNotEmpty;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StoryDetailScreen(storyId: story.id, initialLang: _currentLang),
          ),
        );
      },
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: primary.withAlpha(25),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background: cover image (fills entire card)
            if (hasCover)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _absoluteCoverImageUrl(story.coverImage!),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: borderColor,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: double.infinity,
                color: borderColor,
                child: Center(
                  child: Icon(Icons.menu_book, size: 40, color: primary),
                ),
              ),

            // Foreground: text content (bottom overlay with semi-transparent background)
            Positioned(
              left: 0,
              right: 0,
              bottom: 4, // Space for recommendation indicator bar
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(179), // Dark at bottom
                      Colors.black.withAlpha(77), // Gradient at top
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (story.ethnic.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          story.ethnic,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Top layer: recommendation indicator bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _isRecommended(story)
                      ? secondary.withAlpha(204)
                      : primary.withAlpha(77),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Footer
  Widget _buildFooter(Color textSecondary, Color borderColor) {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _t('storyCount').replaceAll('{count}', '${_displayedStories.length}'),
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 30),
          Text(
            _t('dataSource'),
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}