import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/language_provider.dart';
import '../services/api_services.dart';
import 'bookshelf_screen.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final String initialLang;

  const ProfileScreen({super.key, required this.initialLang});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 统计数据
  int _bookshelfCount = 0;
  int _historyCount = 0;
  int _downloadCount = 0;

  // 存储键名
  final String _bookshelfKey = 'yumai_bookshelf';
  final String _historyKey = 'yumai_history';

  // 多语言文本
  final Map<String, Map<String, String>> _translations = {
    'zh': {
      'title': '我的',
      'userName': '语脉用户',
      'userEmail': 'user@yumai.com',
      'bookshelfLabel': '书架',
      'historyLabel': '历史',
      'downloadLabel': '下载',
      'bookshelfTitle': '书架',
      'bookshelfSubtitle': '您收藏的故事',
      'historyTitle': '历史浏览',
      'historySubtitle': '您看过的故事',
      'downloadTitle': '离线模式',
      'downloadSubtitle': '已下载的故事',
      'settingsLabel': '设置',
      'settingsTitle': '应用设置',
      'settingsSubtitle': '深色模式、关于',
      'aboutTitle': '关于语脉',
      'aboutSubtitle': '版本信息',
      'logout': '退出登录',
      'logoutConfirm': '确定要退出登录吗？',
      'cancel': '取消',
      'confirm': '确定',
      'clearAll': '清空',
    },
    'bo': {
      'title': 'ང་།',
      'userName': 'ཡུ་མའེ་བེད་སྤྱོད་པ།',
      'userEmail': 'user@yumai.com',
      'bookshelfLabel': 'ཕབ་ལེན།',
      'historyLabel': 'ལོ་རྒྱུས།',
      'downloadLabel': 'ལུང་བ།',
      'bookshelfTitle': 'ཕབ་ལེན།',
      'bookshelfSubtitle': 'ཁྱེད་ཀྱི་སྒྲུང་ཕབ་ལེན།',
      'historyTitle': 'ལོ་རྒྱུས།',
      'historySubtitle': 'ཁྱེད་ཀྱི་ལོ་རྒྱུས།',
      'downloadTitle': 'ལུང་བའི་སྒྲུང།',
      'downloadSubtitle': 'ལུང་བར་ཕབ་ལེན་བྱས་པ།',
      'settingsLabel': 'སྒ໲་སྒ໲',
      'settingsTitle': 'གློག་བརྙན་གྱི་སྒ໲་སྒ໲',
      'settingsSubtitle': 'གཤམ་གསལ། གཟུགས་མིང་།',
      'aboutTitle': 'ཡུ་མའེ་གྱི་ངོ་བོ།',
      'aboutSubtitle': 'བརྒྱུད་རིམ།',
      'logout': 'ཕྱིར་འབུད།',
      'logoutConfirm': 'ཕྱིར་འབུད་པར་འདོད་མེད་?',
      'cancel': 'མི་འདོད།',
      'confirm': 'འདོད།',
      'clearAll': 'ཡོངས་སེལ།',
    },
    'ii': {
      'title': 'ꀭꅏ',
      'userName': 'ꒉꃀ ꊿꋅ',
      'userEmail': 'user@yumai.com',
      'bookshelfLabel': 'ꌠꅇꂘ',
      'historyLabel': 'ꐘꀨ',
      'downloadLabel': 'ꌠꅇꂘ',
      'bookshelfTitle': 'ꌠꅇꂘ',
      'bookshelfSubtitle': 'ꀉꂿꄯꒉ ꌠꅇꂘ',
      'historyTitle': 'ꐘꀨ',
      'historySubtitle': 'ꐘꀨ ꌠꅇꂘ',
      'downloadTitle': 'ꌠꅇꂘ ꀉꂿꄯꒉ',
      'downloadSubtitle': 'ꌠꅇꂘ ꀐ',
      'settingsLabel': 'ꌬꇐ',
      'settingsTitle': 'ꌬꇐ ꀉꂿ',
      'settingsSubtitle': 'ꇇꃀꐛ ꑟ',
      'aboutTitle': 'ꀭꅏ ꄜ',
      'aboutSubtitle': 'ꑎꀪ',
      'logout': 'ꌠꅇꂘ',
      'logoutConfirm': 'ꌠꅇꂘ ꀉꂿ?',
      'cancel': 'ꀋꁨ',
      'confirm': 'ꁨ',
      'clearAll': 'ꌠꅇꂘ',
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
    _loadStats();
  }

  // 加载统计数据
  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 书架数量
      final String? bookshelfStr = prefs.getString(_bookshelfKey);
      if (bookshelfStr != null) {
        final List<dynamic> bookshelf = json.decode(bookshelfStr);
        _bookshelfCount = bookshelf.length;
      } else {
        _bookshelfCount = 0;
      }

      // 历史数量（读取 JSON 字符串）
      final String? historyStr = prefs.getString(_historyKey);
      if (historyStr != null) {
        final List<dynamic> historyList = json.decode(historyStr);
        _historyCount = historyList.length;
      } else {
        _historyCount = 0;
      }
      // 下载数量（使用 ApiService 的离线存储）
      _downloadCount = await ApiService.getOfflineStoriesCount();

      setState(() {});
    } catch (e) {
      // print('加载统计数据失败: $e');
    }
  }

  // 退出登录
  Future<void> _logout() async {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSec
        : AppColors.lightTextSec;
    final primary = Theme.of(context).colorScheme.primary;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(_t('logoutConfirm'), style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel'), style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
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
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with language switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title - 艺术渐变字
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, secondary],
                    ).createShader(bounds),
                    child: Text(
                      _t('title'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  // Language switcher
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

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // User info header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('userName'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _t('userEmail'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Settings section header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(
                            _t('settingsLabel'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu items
                    _buildMenuItem(
                      icon: Icons.bookmark,
                      title: _t('bookshelfTitle'),
                      subtitle: _t('bookshelfSubtitle'),
                      badge: _bookshelfCount,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookshelfScreen(initialLang: _currentLang),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildMenuItem(
                      icon: Icons.history,
                      title: _t('historyTitle'),
                      subtitle: _t('historySubtitle'),
                      badge: _historyCount,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                HistoryScreen(initialLang: _currentLang),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildMenuItem(
                      icon: Icons.download,
                      title: _t('downloadTitle'),
                      subtitle: _t('downloadSubtitle'),
                      badge: _downloadCount,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DownloadsScreen(initialLang: _currentLang),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    Container(height: 1, color: borderColor),

                    const SizedBox(height: 24),

                    // Settings menu item
                    _buildMenuItem(
                      icon: Icons.settings,
                      title: _t('settingsTitle'),
                      subtitle: _t('settingsSubtitle'),
                      badge: 0,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        _showSettingsDialog(context);
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildMenuItem(
                      icon: Icons.info_outline,
                      title: _t('aboutTitle'),
                      subtitle: _t('aboutSubtitle'),
                      badge: 0,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),

                    const SizedBox(height: 32),

                    // Logout button
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: danger.withAlpha(25),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: danger),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 18, color: danger),
                            const SizedBox(width: 8),
                            Text(
                              _t('logout'),
                              style: TextStyle(color: danger, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示设置弹窗
  void _showSettingsDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSec
        : AppColors.lightTextSec;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          _t('settingsTitle'),
          style: TextStyle(color: textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem(
              icon: Icons.dark_mode,
              label: '深色模式',
              trailing: Switch(
                value: isDark,
                onChanged: (val) {
                  context.read<ThemeProvider>().toggleTheme();
                  Navigator.pop(context);
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'), style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  // 显示关于弹窗
  void _showAboutDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSec
        : AppColors.lightTextSec;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(_t('aboutTitle'), style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '语脉 YUMAI',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本 1.0.0',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '多语言非物质文化遗产故事阅读与AI问答平台',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('confirm'), style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogItem({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          trailing,
        ],
      ),
    );
  }

  // 菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required int badge,
    required Color primary,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primary.withAlpha(13),
          borderRadius: BorderRadius.circular(16),
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
              child: Icon(icon, size: 24, color: primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondary),
          ],
        ),
      ),
    );
  }
}
