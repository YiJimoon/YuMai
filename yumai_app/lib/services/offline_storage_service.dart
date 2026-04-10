import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/story.dart';

class OfflineStorageService {
  static const String _offlineKey = 'yumai_offline_stories';

  /// 保存故事，返回 true 表示成功，false 表示失败
  static Future<bool> saveStory(Story story) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_offlineKey);
      Map<String, dynamic> offlineMap = {};
      if (data != null) {
        offlineMap = json.decode(data);
      }
      final storyId = story.id.toString();
      final offlineData = {
        'id': story.id,
        'title': story.title,
        'ethnic': story.ethnic,
        'content_zh': story.chineseText,
        'content_yi': story.yiText,
        'content_zang': story.tibetanText,
        'downloadedAt': DateTime.now().toIso8601String(),
      };
      offlineMap[storyId] = offlineData;
      await prefs.setString(_offlineKey, json.encode(offlineMap));
      return true;
    } catch (e) {
      print('saveStory error: $e');  // 使用 print 代替 debugPrint
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllStories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineKey);
    if (data == null) return [];
    final Map<String, dynamic> offlineMap = json.decode(data);
    final stories = offlineMap.values.cast<Map<String, dynamic>>().toList();
    stories.sort((a, b) {
      final aTime = DateTime.tryParse(a['downloadedAt'] ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['downloadedAt'] ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return stories;
  }

  static Future<void> deleteStory(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineKey);
    if (data != null) {
      Map<String, dynamic> offlineMap = json.decode(data);
      offlineMap.remove(storyId);
      await prefs.setString(_offlineKey, json.encode(offlineMap));
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineKey);
  }

  static Future<bool> isDownloaded(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineKey);
    if (data == null) return false;
    final Map<String, dynamic> offlineMap = json.decode(data);
    return offlineMap.containsKey(storyId);
  }

  static Future<Map<String, dynamic>?> getStory(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineKey);
    if (data == null) return null;
    final Map<String, dynamic> offlineMap = json.decode(data);
    return offlineMap[storyId];
  }
}