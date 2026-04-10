import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story.dart';

// 简单语言检测函数
String detectLanguage(String text) {
  if (text.contains(RegExp(r'[\u0F00-\u0FFF]'))) return 'bo';
  if (text.contains(RegExp(r'[\uA000-\uA48F]'))) return 'ii';
  return 'zh';
}

class ApiService {
  // 后端接口基础地址
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String storageKey = 'yumai_offline_stories';

  // 1. 获取故事列表（支持多语言）
  static Future<List<Story>> getStories({String lang = 'zh'}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/stories?lang=$lang'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) => Story.fromListJson(item)).toList();
        }
      }
      // 降级：使用模拟数据（模拟数据只有中文）
      return _getMockStories();
    } catch (e) {
      return _getMockStories();
    }
  }

  /// 模拟故事数据（仅中文）
  static List<Story> _getMockStories() {
    return [
      Story(
        id: 1,
        title: '格萨尔王传',
        ethnic: '藏族',
        intro: '藏族英雄史诗，讲述格萨尔王降妖除魔、造福百姓的传奇故事。',
        chineseText: '''格萨尔王传

在很久很久以前，藏地诞生了一位伟大的英雄——格萨尔王。他降妖除魔，平定四方，为百姓带来了和平与繁荣。

格萨尔王自幼就显露出非凡的神通和智慧。他力大无穷，能降服猛兽；他智勇双全，能识破妖魔的诡计。

长大后，格萨尔王开始了他的英雄征程。他骑着神马，手持宝刀，走遍藏地各地。他战胜了北方魔王鲁赞，最终统一了西藏。

每一次战斗，格萨尔王都是为了保护弱小百姓，为了正义而战。他不仅是一位勇猛的战士，更是一位仁爱之师。

格萨尔王的故事，是藏族人民世代传颂的英雄史诗，也是世界非物质文化遗产的瑰宝。''',
        yiText: '',
        tibetanText: '''༄༅། །གེ་སར་རྒྱལ་པོའི་སྒྲུང་།

དུས་རབས་རིང་པོ་ཞིག་གི་གོང་དུ། བོད་ཀྱི་ཡུལ་དུ་གེ་སར་རྒྱལ་པོ་ཞེས་པའི་དཔའ་བོ་ཆེན་པོ་ཞིག་སྐྱེས་ཏེ། ཁྲག་འཐུང་སྡེ་དགོང་རྣམས་བཏུལ་ནས་མི་དམངས་ལ་བདེ་སྐྱིད་ཀྱི་འཚོ་བ་སྤྲད་པ་ཡིན།

གེ་སར་རྒྱལ་པོ་ནི་སྟོབས་ཆེན་ལྡན་པ་དང་། སྒྱུ་རྩལ་མཁས་པ། མི་དམངས་ཀྱི་དོན་དུ་རང་གི་ཚེ་སྲོག་ཡང་བཞག་འདོད་པའི་དཔའ་བོ་ཞིག་རེད།

དེའི་སྒྲུང་ནི་བོད་ཀྱི་སྒྲུང་གཏམ་ཆེན་པོའི་ནང་གལ་ཆེན་པོ་ཞིག་ཡིན་པ་མ་ཟད། འཛམ་གླིང་གི་སྒྲུང་གཏམ་གྱི་གཞི་རྩའི་ནང་ཀྱང་གྲགས་ཅིག་ཡིན།''',
        coverImage: null,
      ),
      Story(
        id: 2,
        title: '阿诗玛',
        ethnic: '彝族',
        intro: '彝族民间叙事长诗，阿诗玛的传奇故事，展现了彝族人民对美好生活的向往。',
        chineseText: '''阿诗玛

在美丽的石林湖畔，有一个名叫阿诗玛的撒尼姑娘。她像山茶花一样美丽，像清泉一样纯洁。

阿诗玛与勇敢的青年阿黑相爱。他们一起放羊，一起唱歌，过着幸福的生活。

可是，财主热布巴拉看中了阿诗玛，想把她抢去做媳妇。阿黑为了救阿诗玛，与热布巴拉家展开了激烈的斗争。

最后，阿诗玛为了坚守爱情，化作了石林中的一座石峰。她永远守望着这片土地，守望着她深爱的阿黑哥。

阿诗玛的故事，是彝族人民世代传颂的爱情史诗，也是中华民族文化宝库中的瑰宝。''',
        yiText: '''ꀋꏂꃀ ꀉꂿꄯꒉ

ꉡꆹ ꀋꏂꃀ，ꆺꑳꀋꁧ ꑳꉎꀋꄮ ꃄꌠꃄꅉꇬ ꄊꆪꐙꄉ，ꉢꊈꀋꁧ ꇬꄉ ꉢꊈꄈꇈ，ꀋꏂꃀ ꑠꑵ ꉌꊭꀕꑴꌦ。

ꀋꏂꃀ ꆏ ꉌꂵꆏ ꊷꆣꀕ，ꋌꊂꆏ ꀋꁧꄈꌠ，ꀋꏂꃀ ꌺꇖꅀꀋꅐ，ꃅꃄꇖꈓ ꋋꇅꆹ ꉡꆹ ꉌꐡꀋꐥ。

ꀋꏂꃀ ꉌꂵ ꑌ ꐛꀕ，ꉢꊈꀋꁧ ꇬꄉ ꉢꊈꄈꇈ，ꀋꏂꃀ ꑠꑵ ꉌꊭꀕꑴꌦ。''',
        tibetanText: '',
        coverImage: null,
      ),
    ];
  }

  // 1.1 搜索故事（支持多语言）
  static Future<List<Story>> searchStories(String query, {String lang = 'zh'}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(trimmed);
      final uri = Uri.parse('$baseUrl/stories/search?query=$encodedQuery&lang=$lang');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) => Story.fromListJson(item)).toList();
        }
      }

      // 降级：模拟搜索（仅中文）
      final mockStories = _getMockStories();
      return mockStories
          .where(
            (story) =>
                story.title.contains(trimmed) || story.intro.contains(trimmed),
          )
          .toList();
    } catch (e) {
      final mockStories = _getMockStories();
      return mockStories
          .where(
            (story) =>
                story.title.contains(trimmed) || story.intro.contains(trimmed),
          )
          .toList();
    }
  }

  // 2. 获取故事详情（支持多语言）
  static Future<Story?> getStoryDetail(int storyId, {String lang = 'zh'}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/story/$storyId?lang=$lang'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('error')) {
          return _getMockStoryDetail(storyId);
        }
        return Story.fromJson(data);
      } else {
        return _getMockStoryDetail(storyId);
      }
    } catch (e) {
      return _getMockStoryDetail(storyId);
    }
  }

  /// 获取模拟故事详情（用于演示）
  static Story? _getMockStoryDetail(int storyId) {
    final mockStories = _getMockStories();
    final story = mockStories.firstWhere(
      (s) => s.id == storyId,
      orElse: () => mockStories.first,
    );
    return story;
  }

  // 3. 故事问答（已支持 lang 参数）
  static Future<Map<String, dynamic>> askQuestion({
    int? storyId,
    required String question,
    bool useRag = false,
    List<Map<String, String>>? history,
    String lang = 'zh',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'story_id': storyId,
          'question': question,
          'use_rag': useRag,
          'history': history,
          'lang': lang,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 422) {
        return {'error': '参数错误'};
      } else {
        return {'error': '请求失败'};
      }
    } catch (e) {
      return {'error': '网络错误'};
    }
  }

  // 4. 测试后端是否连通
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. 语音转文字
  static Future<String> speechToText(Uint8List audioBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/stt'));
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'voice.wav',
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        try {
          final dynamic decoded = json.decode(responseBody);
          if (decoded is Map<String, dynamic>) {
            final text = (decoded['text'] ?? decoded['result'] ?? '')
                .toString();
            if (text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        } catch (_) {
          // 非 JSON 时直接尝试按纯文本返回
        }
        return responseBody.trim();
      }

      throw Exception('STT 请求失败: ${streamedResponse.statusCode} $responseBody');
    } catch (e) {
      throw Exception('语音识别失败: $e');
    }
  }

  // 6. 文本转语音音频
  static Future<Uint8List?> getTtsAudio(int storyId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tts/$storyId'));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------- 离线存储功能 ----------
  static Future<Map<String, dynamic>> getOfflineStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(storageKey);
      return stored != null ? json.decode(stored) : {};
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveOfflineStory(Story story) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stories = await getOfflineStories();
      stories[story.id.toString()] = story.toJson();
      await prefs.setString(storageKey, json.encode(stories));
    } catch (e) {
      // 忽略保存错误
    }
  }

  static Future<bool> isStoryOffline(int storyId) async {
    final stories = await getOfflineStories();
    return stories.containsKey(storyId.toString());
  }

  static Future<Story?> getOfflineStory(int storyId) async {
    try {
      final stories = await getOfflineStories();
      final jsonData = stories[storyId.toString()];
      return jsonData != null ? Story.fromJson(jsonData) : null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearAllOfflineStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json.encode({}));
    } catch (e) {
      // 忽略清除错误
    }
  }

  static Future<int> getOfflineStoriesCount() async {
    final stories = await getOfflineStories();
    return stories.length;
  }
}