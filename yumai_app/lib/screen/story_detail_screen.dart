import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_services.dart';
import '../services/language_provider.dart';
import '../services/translations.dart';
import '../models/story.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';
import '../services/offline_storage_service.dart';

class StoryDetailScreen extends StatefulWidget {
  final int storyId;
  final String initialLang;

  const StoryDetailScreen({
    super.key,
    required this.storyId,
    required this.initialLang,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  Story? _story;
  bool _isLoading = true;
  String _errorMessage = '';
  String _currentMode = 'read';
  double _readFontSize = 16;
  bool _isInBookshelf = false;
  bool _bookshelfChanged = false;
  final String _bookshelfKey = 'yumai_bookshelf';
  final String _historyKey = 'yumai_history';

  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isAsking = false;
  int _currentSentenceIndex = -1;
  bool _isRecording = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _localLang;

  /// 问答区域语言状态（与正文同步）
  String _qaUiLang = 'zh'; // 当前问答使用的语言
  bool _qaShowLangSwitch = false; // 是否显示语言切换按钮（仅用于判断是否有民族，不再显示）
  String _qaEthnicLang = ''; // 故事原文语言代码

  final Map<String, Map<String, String>> _translations =
      AppTranslations.storyDetail;

  String get _currentLang {
    if (_localLang != null) return _localLang!;
    try {
      return context.watch<LanguageProvider>().currentLang;
    } catch (_) {
      return widget.initialLang;
    }
  }

  String _t(String key) {
  // 使用 listen: false，避免在异步回调中触发重建错误
  final lang = Provider.of<LanguageProvider>(context, listen: false).currentLang;
  final safeLang = ['zh', 'bo', 'ii'].contains(lang) ? lang : 'zh';
  return _translations[safeLang]?[key] ?? _translations['zh']?[key] ?? key;
}

  @override
  void initState() {
    super.initState();
    _loadStoryDetail();
  }

  /// 居中紧凑型 Toast（支持成功/错误样式）
  void _showCenteredToast(String message, {bool isError = false}) {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.5 - 40,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle,
                    color: isError ? Colors.white : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  Future<void> _loadStoryDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final story = await ApiService.getStoryDetail(widget.storyId);
      if (story == null) {
        setState(() {
          _story = null;
          _isLoading = false;
        });
        return;
      }

      await _loadBookshelfStatus(story.id);
      await _addToHistory(story);

      final savedPageIndex = await _getSavedReadingPageIndexDirect(
        widget.storyId,
      );

      // 初始化问答语言状态
      final ethnic = story.ethnic;
      if (ethnic.contains('藏')) {
        _qaShowLangSwitch = true;
        _qaEthnicLang = 'bo';
      } else if (ethnic.contains('彝')) {
        _qaShowLangSwitch = true;
        _qaEthnicLang = 'ii';
      } else {
        _qaShowLangSwitch = false;
      }
      _qaUiLang = 'zh'; // 默认汉语

      setState(() {
        _story = story;
        _isLoading = false;
      });

      if (savedPageIndex > 0 && mounted) {
        _showContinueReadingDialog(story, savedPageIndex);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (mounted) {
        showErrorDialog(context, '${_t('loadFailed')}: $e');
      }
    }
  }

  Future<int> _getSavedReadingPageIndexDirect(int storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_historyKey);
      if (stored == null) return 0;
      final List<dynamic> history = json.decode(stored);
      for (var item in history) {
        if (item['storyId'].toString() == storyId.toString()) {
          return item['readingPageIndex'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('获取阅读位置失败: $e');
    }
    return 0;
  }

  void _showContinueReadingDialog(Story story, int savedPageIndex) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('继续阅读'),
        content: Text('您上次阅读到第 ${savedPageIndex + 1} 页，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('重新开始'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(
                    story: story,
                    initialLang: _currentLang,
                    initialPageIndex: savedPageIndex,
                  ),
                ),
              );
            },
            child: const Text('继续阅读'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBookshelfStatus(int storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_bookshelfKey);
      if (stored == null) {
        _isInBookshelf = false;
        return;
      }
      final bookshelf = List<Map<String, dynamic>>.from(jsonDecode(stored));
      _isInBookshelf = bookshelf.any(
        (item) => item['id'].toString() == storyId.toString(),
      );
    } catch (e) {
      _isInBookshelf = false;
    }
  }

  Future<void> _addToHistory(Story story) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_historyKey);
      List<Map<String, dynamic>> history = stored == null
          ? []
          : List<Map<String, dynamic>>.from(json.decode(stored));

      history.removeWhere(
        (item) => item['storyId'].toString() == story.id.toString(),
      );

      history.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'storyId': story.id,
        'title': story.title,
        'ethnic': story.ethnic,
        'viewedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      debugPrint('${_t('historyFailed')}: $e');
    }
  }

  void _showSnackBar(String message) {
    debugPrint('显示SnackBar: $message');
    if (!mounted) {
      debugPrint('mounted 已失效，跳过 SnackBar');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('callback 时 mounted 已失效，跳过 SnackBar');
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _toggleBookshelf() async {
    if (_story == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_bookshelfKey);
      List<Map<String, dynamic>> bookshelf = stored == null
          ? []
          : List<Map<String, dynamic>>.from(jsonDecode(stored));

      final storyId = _story!.id.toString();
      final exists = bookshelf.any((item) => item['id'].toString() == storyId);

      if (exists) {
        bookshelf.removeWhere((item) => item['id'].toString() == storyId);
        await prefs.setString(_bookshelfKey, jsonEncode(bookshelf));
        if (!mounted) return;
        setState(() => _isInBookshelf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('removedBookshelf')),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        bookshelf.add({
          'id': _story!.id,
          'title': _story!.title,
          'ethnic': _story!.ethnic,
          'addedAt': DateTime.now().toIso8601String(),
        });
        await prefs.setString(_bookshelfKey, jsonEncode(bookshelf));
        if (!mounted) return;
        setState(() => _isInBookshelf = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('addedBookshelf')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      _bookshelfChanged = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('operationFailed')}: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _handleBack() => Navigator.pop(context, _bookshelfChanged);

  String _getCurrentContent() {
    if (_story == null) return '';
    return _story!.getContentByLanguage(_currentLang);
  }

  String _getEthnicLangCode() {
    final ethnic = _story?.ethnic ?? '';
    if (ethnic.contains('藏')) return 'bo';
    if (ethnic.contains('彝')) return 'ii';
    return 'bo';
  }

  String _getEthnicLangLabel() {
    return _getEthnicLangCode() == 'bo'
        ? _t('tibetanOriginal')
        : _t('yiOriginal');
  }

  Future<int> _getSavedReadingPageIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_historyKey);
      if (stored == null) return 0;
      final List<dynamic> history = json.decode(stored);
      for (var item in history) {
        if (item['storyId'].toString() == widget.storyId.toString()) {
          return item['readingPageIndex'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('获取阅读位置失败: $e');
    }
    return 0;
  }

  void _enterReader() {
    if (_story == null) return;
    _getSavedReadingPageIndex().then((pageIndex) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            story: _story!,
            initialLang: _currentLang,
            initialPageIndex: pageIndex,
          ),
        ),
      );
    });
  }

  void _toggleReadLanguage() {
    final ethnicLang = _getEthnicLangCode();
    final newLang = _currentLang == 'zh' ? ethnicLang : 'zh';
    setState(() {
      _localLang = newLang;
      _qaUiLang = newLang; // 添加这一行
    });
  }

  void _showFontSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        double tempSize = _readFontSize;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('readingSettings')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_t('fontSize')}: ${tempSize.toStringAsFixed(0)}'),
                  Slider(
                    min: 14,
                    max: 30,
                    value: tempSize,
                    onChanged: (value) =>
                        setDialogState(() => tempSize = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _readFontSize = tempSize);
                    Navigator.pop(context);
                  },
                  child: Text(_t('confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'[。！？\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
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

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: LoadingOverlay(
            isLoading: _isLoading,
            child: _errorMessage.isNotEmpty
                ? _buildErrorView(textPrimary, textSecondary, primary)
                : _story == null
                ? Center(
                    child: Text(
                      _t('storyNotFound'),
                      style: TextStyle(color: textPrimary),
                    ),
                  )
                : _buildContent(
                    primary,
                    secondary,
                    surfaceColor,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(
    Color textPrimary,
    Color textSecondary,
    Color primary,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(_t('loadFailed2'), style: TextStyle(color: textPrimary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStoryDetail, child: Text(_t('retry'))),
        ],
      ),
    );
  }

  Widget _buildContent(
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final sentences = _splitSentences(_getCurrentContent());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 顶部导航
        _buildHeader(
          primary,
          secondary,
          surfaceColor,
          borderColor,
          textPrimary,
          textSecondary,
          isDark,
        ),

        // 内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // 标题区
                _buildTitleSection(textPrimary, secondary, isDark),

                const SizedBox(height: 16),

                // 简介
                _buildIntroSection(
                  textPrimary,
                  textSecondary,
                  surfaceColor,
                  borderColor,
                ),

                const SizedBox(height: 20),

                // 模式切换
                _buildModeSwitch(
                  primary,
                  surfaceColor,
                  borderColor,
                  textPrimary,
                  isDark,
                ),

                const SizedBox(height: 16),

                // 内容
                _currentMode == 'read'
                    ? _buildReadMode(
                        primary,
                        textPrimary,
                        borderColor,
                        surfaceColor,
                      )
                    : _buildRepeatMode(
                        sentences,
                        primary,
                        secondary,
                        textPrimary,
                        borderColor,
                        surfaceColor,
                        isDark,
                      ),

                const SizedBox(height: 20),

                // 问答区
                _buildQASection(
                  primary,
                  secondary,
                  surfaceColor,
                  borderColor,
                  textPrimary,
                  textSecondary,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: _handleBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withAlpha(77)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _t('back'),
                    style: TextStyle(
                      color: primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 语言切换
          GestureDetector(
            onTap: _toggleReadLanguage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: primary.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate, color: primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _currentLang == 'zh'
                        ? _getEthnicLangLabel()
                        : _t('chinese'),
                    style: TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 书架
          _HeaderIconButton(
            icon: _isInBookshelf ? Icons.bookmark : Icons.bookmark_border,
            color: primary,
            onTap: _toggleBookshelf,
          ),

          const SizedBox(width: 4),

          // 设置

          // 下载按钮（带验证逻辑）
          _HeaderIconButton(
            icon: Icons.download_outlined,
            color: textSecondary,
            onTap: () async {
              if (_story == null) {
                _showCenteredToast(_t('storyNotFound'), isError: true);
                return;
              }
              try {
                await OfflineStorageService.saveStory(_story!);
                // 验证是否真的保存成功
                final isSaved = await OfflineStorageService.isDownloaded(
                    _story!.id.toString());
                if (isSaved) {
                  _showCenteredToast(_t('downloaded'), isError: false);
                } else {
                  _showCenteredToast('保存失败，请重试', isError: true);
                }
              } catch (e) {
                debugPrint('保存异常: $e');
                _showCenteredToast('保存失败: ${e.toString().substring(0, 30)}',
                    isError: true);
              }
            },
          ),

          const SizedBox(width: 4),

          // 进入沉浸式阅读器
          _HeaderIconButton(
            icon: Icons.auto_stories_rounded,
            color: primary,
            onTap: _enterReader,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(Color textPrimary, Color secondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _story!.title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: secondary.withAlpha(38),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _story!.ethnic,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroSection(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        _story!.intro,
        style: TextStyle(fontSize: 14, color: textSecondary, height: 1.6),
      ),
    );
  }

  Widget _buildModeSwitch(
    Color primary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    bool isDark,
  ) {
    return Row(
      children: [
        _buildModeButton(
          'read',
          _t('reading'),
          Icons.menu_book_rounded,
          primary,
          surfaceColor,
          borderColor,
          textPrimary,
          isDark,
        ),
        const SizedBox(width: 12),
        _buildModeButton(
          'repeat',
          _t('repeatReading'),
          Icons.mic_rounded,
          primary,
          surfaceColor,
          borderColor,
          textPrimary,
          isDark,
        ),
      ],
    );
  }

  Widget _buildModeButton(
    String mode,
    String label,
    IconData icon,
    Color primary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    bool isDark,
  ) {
    final isActive = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primary : surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? primary : borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : textPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : textPrimary,
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

  Widget _buildReadMode(
    Color primary,
    Color textPrimary,
    Color borderColor,
    Color surfaceColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _getCurrentContent();
    final preview = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
              : [const Color(0xFFF5F0E8), const Color(0xFFEDE7DA)],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary.withAlpha(15), primary.withAlpha(0)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: textPrimary.withAlpha(179),
                    fontFamily: _currentLang == 'bo'
                        ? 'Noto Serif Tibetan'
                        : _currentLang == 'ii'
                        ? 'Noto Sans Yi'
                        : null,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _enterReader,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withAlpha(204)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withAlpha(77),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _t('enterReading'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatMode(
    List<String> sentences,
    Color primary,
    Color secondary,
    Color textPrimary,
    Color borderColor,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _t('repeatReading'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${_currentSentenceIndex >= 0 ? _currentSentenceIndex + 1 : "-"} / ${sentences.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textPrimary.withAlpha(179),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: sentences.length,
              itemBuilder: (context, index) {
                final sentence = sentences[index];
                final isActive = _currentSentenceIndex == index;
                final badgeColors = [
                  primary,
                  secondary,
                  primary.withAlpha(179),
                  secondary.withAlpha(179),
                ];
                final badgeColor = badgeColors[index % badgeColors.length];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentSentenceIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? primary.withAlpha(15)
                          : isDark
                          ? Colors.white.withAlpha(13)
                          : Colors.black.withAlpha(13),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive ? primary : borderColor,
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: primary.withAlpha(25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? primary
                                      : badgeColor.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? Colors.white
                                          : badgeColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(
                                  sentence,
                                  style: TextStyle(
                                    fontSize: _readFontSize - 3,
                                    height: 1.5,
                                    color: textPrimary,
                                    fontFamily: _currentLang == 'bo'
                                        ? 'Noto Serif Tibetan'
                                        : _currentLang == 'ii'
                                        ? 'Noto Sans Yi'
                                        : null,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildIconButton(
                              icon: Icons.play_arrow_rounded,
                              color: primary,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_t('playing')}: $sentence',
                                    ),
                                    duration: const Duration(milliseconds: 800),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            _buildIconButton(
                              icon: Icons.mic_rounded,
                              color: primary,
                              onTap: () {
                                setState(() {
                                  if (_isRecording &&
                                      _currentSentenceIndex == index) {
                                    _isRecording = false;
                                    _currentSentenceIndex = -1;
                                  } else {
                                    _isRecording = true;
                                    _currentSentenceIndex = index;
                                  }
                                });
                              },
                              isActive:
                                  _isRecording &&
                                  _currentSentenceIndex == index,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? color : color.withAlpha(25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.white : color, size: 22),
      ),
    );
  }

  Widget _buildQASection(
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _t('qa'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              if (_chatMessages.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _chatMessages.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: textSecondary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _t('clear'),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_chatMessages.isEmpty)
            _buildEmptyState(textSecondary, secondary)
          else
            _buildMessageList(
              primary,
              secondary,
              surfaceColor,
              borderColor,
              textPrimary,
              textSecondary,
              isDark,
            ),
          const SizedBox(height: 16),
          _buildInputArea(
            primary,
            secondary,
            surfaceColor,
            borderColor,
            textPrimary,
            textSecondary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary, Color secondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: secondary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 32,
              color: secondary.withAlpha(179),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t('askPrompt'), // 改为 _t
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('examplePrompt'), // 改为 _t
            style: TextStyle(fontSize: 12, color: textSecondary.withAlpha(153)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withAlpha(77)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _chatMessages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final message = _chatMessages[index];
          final isUser = message['role'] == 'user';
          return isUser
              ? _buildUserBubble(message['content']!, primary, textPrimary)
              : _buildAIBubble(
                  message['content']!,
                  primary,
                  secondary,
                  textPrimary,
                  textSecondary,
                  isDark,
                  borderColor,
                );
        },
      ),
    );
  }

  Widget _buildUserBubble(String content, Color primary, Color textPrimary) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withAlpha(204)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withAlpha(51),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '我',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIBubble(
    String content,
    Color primary,
    Color secondary,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    Color borderColor,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(13) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: borderColor.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 25 : 13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 助手',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(
    Color primary,
    Color secondary,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withAlpha(102)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: _t('inputQuestion'),
                hintStyle: TextStyle(
                  color: textSecondary.withAlpha(153),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _isAsking ? null : _askQuestion(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isAsking ? null : _askQuestion,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: _isAsking
                    ? null
                    : LinearGradient(
                        colors: [primary, secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isAsking ? textSecondary.withAlpha(77) : null,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isAsking
                    ? null
                    : [
                        BoxShadow(
                          color: primary.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: _isAsking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textSecondary,
                        ),
                      ),
                    )
                  : Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    final detectedLang = detectLanguage(question);

    setState(() {
      _isAsking = true;
      _chatMessages.add({'role': 'user', 'content': question});
    });

    try {
      final historyLength = _chatMessages.length - 1;
      final history = historyLength > 0
          ? _chatMessages
                .take(historyLength)
                .map(
                  (m) => {
                    'role': m['role'] == 'user' ? 'user' : 'assistant',
                    'content': m['content']!,
                  },
                )
                .toList()
          : null;

      final result = await ApiService.askQuestion(
        storyId: widget.storyId,
        question: question,
        useRag: false,
        history: history,
        lang: detectedLang, // 改为自动检测的语言
      );

      setState(() {
        String answer;
        if (result.containsKey('answer')) {
          answer = result['answer'] ?? '';
        } else if (result.containsKey('error')) {
          answer = '${_t('error')}: ${result['error']}';
        } else {
          answer = result.toString();
        }
        _chatMessages.add({'role': 'ai', 'content': answer});
        _isAsking = false;
        _questionController.clear();
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'role': 'ai',
          'content': '${_t('requestFailed')}: $e',
        });
        _isAsking = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _questionController.dispose();
    super.dispose();
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}